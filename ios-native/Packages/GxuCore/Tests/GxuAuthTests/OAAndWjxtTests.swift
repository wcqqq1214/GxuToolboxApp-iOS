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

    @Test func loginFailureSurfacesServerMessage() async {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, #"{"code":401,"message":"账号或密码错误","result":null}"#) }
        let (session, tokens) = make()
        await #expect(throws: GxuError.invalidData("账号或密码错误")) { try await session.login(username: "u", password: "bad") }
        #expect(tokens.load() == nil)
    }

    @Test func blockedNetworkExplainsCampusRequirement() async {
        StubURLProtocol.register(host: "oa.gxu.edu.cn") { reply($0, status: 403, "<html>访问出错 - 403</html>") }
        let (session, _) = make()
        await #expect(throws: GxuError.http(status: 403, message: "OA 系统拒绝访问，可能需要连接校园网")) { try await session.login(username: "u", password: "p") }
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

    @Test func noCredentialThrowsNotLoggedIn() async {
        let (session, _) = make(creds: [:])
        await #expect(throws: GxuError.notLoggedIn(.oa)) { _ = try await session.json("GET", path: "/x") }
    }

    @Test func downloadRejectsNonSchoolHosts() async {
        let (session, _) = make(tokens: InMemoryTokenStore("T"))
        await #expect(throws: GxuError.invalidData("不支持的文件地址")) { _ = try await session.download(URL(string: "https://evil.example.com/a.pdf")!) }
        await #expect(throws: GxuError.invalidData("不支持的文件地址")) { _ = try await session.download(URL(string: "http://oa.gxu.edu.cn/a.pdf")!) }
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
