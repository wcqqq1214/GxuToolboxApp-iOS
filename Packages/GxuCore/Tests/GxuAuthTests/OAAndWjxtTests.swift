import Foundation
import GxuFoundation
import GxuTestSupport
import Synchronization
import Testing
@testable import GxuAuth

private func reply(_ request: URLRequest, status: Int = 200, _ body: String) -> (HTTPURLResponse, Data) {
    (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, Data(body.utf8))
}

private let loginOK = #"{"code":200,"type":"success","message":"","result":{"accessToken":"T-1","refreshToken":"R","needSelectOrg":false}}"#

/// OA 用固定域名（oa.gxu.edu.cn），串行执行避免 handler 互相覆盖
@Suite(.serialized)
struct OASessionTests {
    private func make(tokens: InMemoryTokenStore = InMemoryTokenStore(), creds: [AuthSystem: Credential] = [.oa: Credential(username: "u", password: "p")]) -> (OASession, InMemoryTokenStore) {
        (OASession(credentials: InMemoryCredentialStore(creds), tokens: tokens, configuration: StubURLProtocol.makeConfiguration()), tokens)
    }

    @Test func loginStoresToken() async throws {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, loginOK) }
        let (session, tokens) = make()
        try await session.login(username: "u", password: "p")
        #expect(tokens.load() == "T-1")
    }

    @Test func clearingSessionWhileRenewalIsInFlightDiscardsItsToken() async throws {
        let response = DelayedStubResponse()
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { request in
            try response.hold()
            return reply(request, loginOK)
        }
        let (session, tokens) = make()
        let renewal = Task { try await session.ensureToken() }
        defer { response.release(); renewal.cancel() }

        try await response.waitForRequest()
        await session.clear()
        response.release()
        await #expect(throws: CancellationError.self) { try await renewal.value }
        #expect(tokens.load() == nil)
    }

    @Test func loginFailureSurfacesServerMessage() async {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, #"{"code":401,"message":"账号或密码错误","result":null}"#) }
        let (session, tokens) = make()
        await #expect(throws: GxuError.credentialsRejected(.oa, "账号或密码错误")) { try await session.login(username: "u", password: "bad") }
        #expect(tokens.load() == nil)
    }

    /// 服务端明确拒绝时直接转述它的文案；没有文案就不替它说是密码错了
    @Test func serverRejectionIsRelayedAndEmptyMessageStaysNeutral() async {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, #"{"code":400,"type":"error","message":"[D1000] 账号或密码不正确","result":null}"#) }
        let (session, _) = make()
        await #expect(throws: GxuError.credentialsRejected(.oa, "[D1000] 账号或密码不正确")) { try await session.login(username: "u", password: "p") }
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, #"{"code":500,"type":"error","message":"","result":null}"#) }
        do { try await session.login(username: "u", password: "p"); Issue.record("应该失败") } catch {
            let message = (error as? GxuError)?.userMessage ?? ""
            #expect(message.contains("没有给出原因") && !message.contains("账号和密码"))
        }
    }

    /// 200 但不是 JSON（WAF 页面等）：说「意料之外的内容 / 可能需要校园网」，不说账号密码，也写进诊断日志
    @Test func htmlInsteadOfJsonIsNotBlamedOnThePassword() async {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, "<html>访问出错 - 403</html>") }
        let (session, _) = make()
        do { try await session.login(username: "u", password: "S3cretPw"); Issue.record("应该失败") } catch {
            let message = (error as? GxuError)?.userMessage ?? ""
            #expect(message.contains("校园网") && !message.contains("账号"))
        }
        let log = ErrorLog.shared.contents()
        #expect(log.contains("OA 登录：响应不是 JSON"))
        #expect(!log.contains("S3cretPw"))
    }

    /// 诊断日志要记服务端的 message（不含密码），否则查不出被拒绝的原因；密码本身不能出现在日志里
    @Test func rejectionLogKeepsTheServerMessageButNeverThePassword() async {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, #"{"code":400,"type":"error","message":"[D1000] 账号或密码不正确","result":null}"#) }
        let (session, _) = make()
        _ = try? await session.login(username: "u", password: "S3cretPw!")
        let log = ErrorLog.shared.contents()
        #expect(log.contains("OA 登录被服务端拒绝（code 400"))
        #expect(log.contains("message：[D1000] 账号或密码不正确"))
        #expect(!log.contains("S3cretPw!"))
    }

    @Test func serverErrorStatusIsReportedAsHTTP() async {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, status: 502, "bad gateway") }
        let (session, _) = make()
        await #expect(throws: GxuError.http(status: 502, message: nil)) { try await session.login(username: "u", password: "p") }
    }

    @Test func blockedNetworkExplainsCampusRequirement() async {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, status: 403, "<html>访问出错 - 403</html>") }
        let (session, _) = make()
        await #expect(throws: GxuError.http(status: 403, message: "OA 系统拒绝访问，可能需要连接校园网或 VPN。")) { try await session.login(username: "u", password: "p") }
    }

    @Test func requestsCarryBearerAndRetryAfterRelogin() async throws {
        let seenAuth = Mutex<[String]>([])
        let calls = Mutex(0)
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { request in
            if request.url!.path.hasSuffix("/auth/login") { return reply(request, loginOK) }
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            seenAuth.withLock { $0.append(auth) }
            let n = calls.withLock { $0 += 1; return $0 }
            return n == 1 ? reply(request, status: 401, "{}") : reply(request, #"{"code":200,"result":{"ok":true}}"#)
        }
        let (session, tokens) = make(tokens: InMemoryTokenStore("OLD"))
        let data = try await session.json("GET", path: "/wenjian/detail", query: ["id": "1"])
        #expect(String(decoding: data, as: UTF8.self).contains("\"ok\""))
        #expect(seenAuth.withLock { $0 } == ["Bearer OLD", "Bearer T-1"])
        #expect(tokens.load() == "T-1")
    }

    @Test func secondUnauthorizedThrowsSessionExpired() async {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { request in
            request.url!.path.hasSuffix("/auth/login") ? reply(request, loginOK) : reply(request, status: 401, "{}")
        }
        let (session, _) = make(tokens: InMemoryTokenStore("OLD"))
        await #expect(throws: GxuError.sessionExpired(.oa)) { _ = try await session.json("GET", path: "/x") }
    }

    /// OA：服务器明确拒绝 → 需要重新登录；网络错误 / 非 JSON / 5xx 不改变状态
    @MainActor
    @Test func oaStateFollowsOnlyExplicitRejections() async throws {
        func center(_ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) -> (AccountCenter, OASession) {
            StubURLProtocol.register(host: "oa.gxu.edu.cn", handler: handler)
            let creds = InMemoryCredentialStore([.oa: Credential(username: "u", password: "p")])
            let oa = OASession(credentials: creds, tokens: InMemoryTokenStore(), configuration: StubURLProtocol.makeConfiguration())
            return (AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: BackendClientForTests.make()), oa: oa), oa)
        }
        func settle() async { try? await Task.sleep(for: .milliseconds(300)) }

        for (name, handler) in [
            ("网络错误", { @Sendable (_: URLRequest) throws -> (HTTPURLResponse, Data) in throw URLError(.notConnectedToInternet) }),
            ("5xx", { @Sendable r in reply(r, status: 503, "unavailable") }),
            ("403", { @Sendable r in reply(r, status: 403, "<html/>") }),
            ("非 JSON", { @Sendable r in reply(r, "<html>waf</html>") }),
            ("服务端别的错误 code", { @Sendable r in reply(r, #"{"code":500,"message":"服务异常","result":null}"#) }),
        ] as [(String, @Sendable (URLRequest) throws -> (HTTPURLResponse, Data))] {
            let (center, oa) = center(handler)
            #expect(center.states[.oa] == .authenticated)
            _ = try? await oa.ensureToken()
            await settle()
            #expect(center.states[.oa] == .authenticated, "OA \(name) 不该改变登录状态")
        }

        let (rejected, oa) = center { reply($0, #"{"code":400,"type":"error","message":"[D1000] 账号或密码不正确","result":null}"#) }
        _ = try? await oa.ensureToken()
        await settle()
        #expect(rejected.states[.oa] == .signedOut)
        #expect(rejected.states[.oa]?.displayText == "需要重新登录")
        await #expect(throws: GxuError.sessionExpired(.oa)) { try await rejected.ensureAuthenticated(.oa) }
        await rejected.logout(.oa)
        #expect(rejected.states[.oa] == .noAccount)
    }

    @Test func noCredentialThrowsNotLoggedIn() async {
        let (session, _) = make(creds: [:])
        await #expect(throws: GxuError.notLoggedIn(.oa)) { _ = try await session.json("GET", path: "/x") }
    }

    @Test func downloadRejectsNonSchoolHosts() async {
        let (session, _) = make(tokens: InMemoryTokenStore("T"))
        await #expect(throws: GxuError.invalidData("不支持的文件地址")) { _ = try await session.download(URL(string: "https://evil.example.com/a.pdf")!) }
        await #expect(throws: GxuError.invalidData("不支持的文件地址")) { _ = try await session.download(URL(string: "http://oa.gxu.edu.cn/a.pdf")!) }
    }

    /// 回归：旧实现用 hasSuffix("gxu.edu.cn")，`evilgxu.edu.cn` 会通过并收到 Bearer token
    @Test func downloadRejectsLookalikeHostAndNeverSendsToken() async {
        let hit = Mutex(false)
        StubURLProtocol.register(host: "evilgxu.edu.cn") { request in hit.withLock { $0 = true }; return reply(request, "%PDF") }
        let (session, _) = make(tokens: InMemoryTokenStore("SECRET"))
        await #expect(throws: GxuError.invalidData("不支持的文件地址")) { _ = try await session.download(URL(string: "https://evilgxu.edu.cn/a.pdf")!) }
        #expect(!hit.withLock { $0 })
    }

    @Test func bearerTokenOnlyGoesToTheOAHost() async throws {
        let seen = Mutex<[String: String]>([:])
        for host in ["oa.gxu.edu.cn", "static.gxu.edu.cn"] {
            StubURLProtocol.register(host: host) { request in
                seen.withLock { $0[host] = request.value(forHTTPHeaderField: "Authorization") ?? "none" }
                return reply(request, "%PDF")
            }
        }
        let (session, _) = make(tokens: InMemoryTokenStore("SECRET"))
        _ = try await session.download(URL(string: "https://oa.gxu.edu.cn/f/1.pdf")!)
        _ = try await session.download(URL(string: "https://static.gxu.edu.cn/f/2.pdf")!)
        #expect(seen.withLock { $0 } == ["oa.gxu.edu.cn": "Bearer SECRET", "static.gxu.edu.cn": "none"])
    }

    /// 回归：旧实现直接用 lastPathComponent，`..%2F..%2Fx.pdf` 能写出临时目录；没有扩展名时 QuickLook 无法预览
    @Test func downloadKeepsFilesInsideItsDirectoryAndAddsExtension() async throws {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { request in
            let type = request.url!.path.contains("word") ? "application/vnd.openxmlformats-officedocument.wordprocessingml.document" : "application/octet-stream"
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": type])!, Data("x".utf8))
        }
        let (session, _) = make(tokens: InMemoryTokenStore("T"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("oa-preview").standardizedFileURL.path
        let traversal = try await session.download(URL(string: "https://oa.gxu.edu.cn/x/..%2F..%2F..%2Fescaped.pdf")!)
        #expect(traversal.standardizedFileURL.path.hasPrefix(root + "/"))
        #expect(traversal.pathExtension == "pdf")
        let noExt = try await session.download(URL(string: "https://oa.gxu.edu.cn/api/gxuoa/download?id=7")!, preferredExtension: "pdf")
        #expect(noExt.pathExtension == "pdf")
        let byType = try await session.download(URL(string: "https://oa.gxu.edu.cn/word/download")!)
        #expect(byType.pathExtension == "docx")
        let a = try await session.download(URL(string: "https://oa.gxu.edu.cn/a/same.pdf")!)
        let b = try await session.download(URL(string: "https://oa.gxu.edu.cn/b/same.pdf")!)
        #expect(a != b)   // 同名文件各自一个目录，不会互相覆盖
    }

    @Test func safeFileNameNeverEscapesAndPrefersKnownExtensions() {
        func name(_ url: String, type: String? = nil, ext: String? = nil) -> String {
            OASession.safeFileName(for: URL(string: url)!, contentType: type, preferredExtension: ext)
        }
        #expect(name("https://oa.gxu.edu.cn/a/..%2F..%2Fetc%2Fpasswd") == "passwd")
        #expect(!name("https://oa.gxu.edu.cn/a/....%2F....%2Fx.pdf").contains("/"))
        #expect(!name("https://oa.gxu.edu.cn/a/....%2F....%2Fx.pdf").contains(".."))
        #expect(name("https://oa.gxu.edu.cn/a/通知 正文.pdf") == "通知_正文.pdf")
        #expect(name("https://oa.gxu.edu.cn/a/") == "a")
        #expect(name("https://oa.gxu.edu.cn/", ext: "docx") == "file.docx")
        #expect(name("https://oa.gxu.edu.cn/a/x", type: "application/pdf", ext: "docx") == "x.pdf")   // Content-Type 优先
        #expect(name("https://oa.gxu.edu.cn/a/x.exe", ext: "exe") == "x.exe")                             // 不认识的扩展名不乱补
    }

    /// 回归：换 OA 账号时不能留着上一个账号的问卷系统会话（放在这个串行套件里，因为它用固定域名 oa.gxu.edu.cn）
    @MainActor
    @Test func switchingOAAccountDropsThePreviousWjxtSession() async throws {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, loginOK) }
        let creds = InMemoryCredentialStore()
        let wjxt = WjxtSession(credentials: creds, configuration: StubURLProtocol.makeConfiguration())
        wjxt.cookies.setCookie(HTTPCookie(properties: [.name: "ASP.NET_SessionId", .value: "SESS1", .domain: "wjxt.gxu.edu.cn", .path: "/"])!)
        let oa = OASession(credentials: creds, tokens: InMemoryTokenStore(), configuration: StubURLProtocol.makeConfiguration())
        let center = AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: BackendClientForTests.make()), oa: oa, wjxt: wjxt)
        try await center.login(.oa, username: "new-account", password: "pw")
        #expect(wjxt.sessionCookies().isEmpty)
    }

    @MainActor
    @Test func accountCenterLoginAndLogoutOA() async throws {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, loginOK) }
        let creds = InMemoryCredentialStore()
        let tokens = InMemoryTokenStore()
        let oa = OASession(credentials: creds, tokens: tokens, configuration: StubURLProtocol.makeConfiguration())
        let client = BackendClientForTests.make()
        let center = AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: client), oa: oa)
        try await center.login(.oa, username: " idcard ", password: "pw")
        #expect(center.states[.oa] == .authenticated)
        #expect(creds.load(.oa) == Credential(username: "idcard", password: "pw"))
        await center.logout(.oa)
        #expect(tokens.load() == nil && creds.load(.oa) == nil)
        #expect(center.states[.oa] == .noAccount)
    }
}

import GxuNetworking
private enum BackendClientForTests {
    static func make() -> BackendClient { BackendClient(session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration())) }
}

struct WjxtParsingTests {
    private let html = """
    <html><body>
    <span><a href="WjxtFile.aspx?id=123">关于召开会议的通知</a></span><span>2026-11-01</span><span>办公室</span>
    <span><a href="WjxtFile.aspx?id=456">问卷调查</a></span><span>2026-10-30</span><span>学工部</span>
    <span>   </span>
    </body></html>
    """

    @Test func groupsSpansByThreeAndExtractsIds() {
        let files = WjxtSession.parsePending(html)
        #expect(files.count == 2)
        #expect(files[0] == WjxtPendingFile(content: "关于召开会议的通知-2026-11-01-办公室", id: "123", href: "WjxtFile.aspx?id=123"))
        #expect(files[1].id == "456")
    }

    @Test func decodesGB2312Pages() {
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        let data = "<span>统一认证登录</span>".data(using: encoding)!
        #expect(WjxtSession.decodeGB(data) == "<span>统一认证登录</span>")
    }

    @Test func loginFailureIsDetectedByAlertScript() {
        #expect(WjxtSession.isLoginFailure("<script>alert('密码错误')</script>"))
        #expect(!WjxtSession.isLoginFailure(html))
    }

    @Test func formEncodingEscapesSpecialCharacters() {
        #expect(WjxtSession.encode("a b&c=d+1") == "a%20b%26c%3Dd%2B1")
    }
}
