import Foundation
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Synchronization
import Testing
@testable import GxuAuth

private let pubKey = #"{"modulus":"a170b33839263059f28c105d1fb17c2390c192cfd3ac94af0f21ddb66cad4a268d116ece1738f7d93d9c172411e20b8f6b0d549b6f03675a1600a35a099950d836f675cc81e74ef5e8e25d940ed904759531985d5d9dc9f81818e811892f902bd23f0824128b2f330c5c7fd0a6a3a4506513270e269e0d37f2a74de452e6b439","exponent":"10001"}"#
private let loginPage = #"<form id="fm1" action="/zfca/login" method="post"><input type="hidden" name="execution" value="abc-123_XYZ"/></form>"#

private final class TokenCheckBody: @unchecked Sendable {
    static let realShape = #"[{"localeKey":"zh_CN","row_id":"1","doType":null,"pageable":false,"queryModel":{}}]"#
    private let storage = Mutex(TokenCheckBody.realShape)
    var value: String { get { storage.withLock { $0 } } set { storage.withLock { $0 = newValue } } }
}
private let tokenCheckBody = TokenCheckBody()

private final class Counter: @unchecked Sendable {
    private let storage = Mutex(0)
    @discardableResult func increment() -> Int { storage.withLock { $0 += 1; return $0 } }
    var value: Int { storage.withLock { $0 } }
}

private func reply(_ request: URLRequest, status: Int = 200, headers: [String: String] = [:], _ body: String = "") -> (HTTPURLResponse, Data) {
    (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!, Data(body.utf8))
}

private func bodyString(_ request: URLRequest) -> String {
    if let body = request.httpBody { return String(decoding: body, as: UTF8.self) }
    guard let stream = request.httpBodyStream else { return "" }
    stream.open(); defer { stream.close() }
    var data = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: 1024); if n <= 0 { break }; data.append(buffer, count: n) }
    return String(decoding: data, as: UTF8.self)
}

private final class DeferredUnifiedRejection: URLProtocol, @unchecked Sendable {
    private static let pending = Mutex<DeferredUnifiedRejection?>(nil)

    override class func canInit(with request: URLRequest) -> Bool {
        request.httpMethod == "POST" && request.url?.query?.contains("caslogin") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.pending.withLock { $0 = self }
    }

    override func stopLoading() {}

    static func waitForRequest() async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !pending.withLock({ $0 != nil }) {
            guard ContinuousClock.now < deadline else { throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    static func release() {
        let stub = pending.withLock { value in
            let stub = value
            value = nil
            return stub
        }
        guard let stub, let client = stub.client else { return }
        let page = loginPage.replacingOccurrences(of: "</form>", with: #"<p id="errormsg">密码错误</p></form>"#)
        let (response, data) = reply(stub.request, page)
        client.urlProtocol(stub, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(stub, didLoad: data)
        client.urlProtocolDidFinishLoading(stub)
    }
}

@Suite(.serialized)
struct UnifiedAuthTests {
    private func makeSession(password: String = "pw") -> UnifiedAuthSession {
        let store = InMemoryCredentialStore([.unified: Credential(username: "2025001", password: password)])
        return UnifiedAuthSession(credentials: store, configuration: StubURLProtocol.makeConfiguration())
    }

    @Test func engTrainingFlowFollowsRedirectsAndGetsToken() async throws {
        let posted = Mutex<String>("")
        StubURLProtocol.register(host: "ca.gxu.edu.cn") { request in
            let path = request.url!.path
            if path.hasSuffix("getPubKey") { return reply(request, pubKey) }
            if request.httpMethod == "POST" {
                posted.withLock { $0 = bodyString(request) + "|" + (request.url!.query ?? "") }
                return reply(request, status: 302, headers: ["Location": "http://xlzxms.gxu.edu.cn/api/security-server/dietc/loginsso/student?ticket=ST-1"])
            }
            return reply(request, loginPage)
        }
        StubURLProtocol.register(host: "xlzxms.gxu.edu.cn") { request in
            let path = request.url!.path
            if path.hasSuffix("loginsso/student") { return reply(request, status: 302, headers: ["Location": "/page/index?studentCode=S42"]) }
            if path.hasSuffix("authorizing/loginsso") { return reply(request, #"{"datas":{"token":"TKN"}}"#) }
            return reply(request, "<html/>")
        }
        let result = try await makeSession().loginEngTraining()
        #expect(result == EngTrainingSession(studentCode: "S42", token: "TKN"))
        let body = posted.withLock { $0 }
        #expect(body.contains("username=2025001") && body.contains("execution=abc-123_XYZ") && body.contains("_eventId=submit"))
        #expect(body.contains("service=http://xlzxms.gxu.edu.cn/api/security-server/dietc/loginsso/student") || body.contains("service=http%3A"))
        #expect(!body.contains("password=pw"))
    }

    @Test func loginPageWithServerMessageIsRelayedAndWithoutOneIsNeutral() async {
        let reason = Mutex("用户名或密码错误")
        StubURLProtocol.register(host: "ca.gxu.edu.cn") { request in
            let path = request.url!.path
            if path.hasSuffix("getPubKey") { return reply(request, pubKey) }
            if path.hasSuffix("getKaptchaStatus") { return reply(request, "false") }
            let page = loginPage.replacingOccurrences(of: "</form>", with: "<p class=\"error text-left\" id=\"errormsg\">\(reason.withLock { $0 })</p></form>")
            return reply(request, page)
        }
        let session = makeSession()
        await #expect(throws: GxuError.credentialsRejected(.unified, "统一认证提示：用户名或密码错误")) { try await session.loginPEC() }
        reason.withLock { $0 = "" }
        do { try await session.loginPEC(); Issue.record("应该失败") } catch {
            let message = (error as? GxuError)?.userMessage ?? ""
            #expect(message.contains("没有说明原因"))
            #expect(!message.contains("账号或密码"))
        }
    }

    @Test func serviceLoginWithoutAccountThrowsNotLoggedIn() async {
        let session = UnifiedAuthSession(credentials: InMemoryCredentialStore(), configuration: StubURLProtocol.makeConfiguration())
        await #expect(throws: GxuError.notLoggedIn(.unified)) { try await session.loginPEC() }
    }

    @Test func parsesExecutionInEitherAttributeOrder() {
        #expect(UnifiedAuthSession.execution(in: Data(loginPage.utf8)) == "abc-123_XYZ")
        #expect(UnifiedAuthSession.execution(in: Data(#"<input value="v-1" type="hidden" name="execution">"#.utf8)) == "v-1")
        #expect(UnifiedAuthSession.execution(in: Data("<html/>".utf8)) == nil)
    }

    @Test func extractsStudentCodeFromLandingURL() {
        #expect(UnifiedAuthSession.studentCode(from: URL(string: "http://x/a?b=CODE9")!) == "CODE9")
        #expect(UnifiedAuthSession.studentCode(from: URL(string: "http://x/a")!) == nil)
    }


    private func registerCAFlow(kaptcha: String = "false", loginSucceeds: Bool = true, tokenCheckWorks: Bool = true,
                                tokenHits: Counter = Counter(), postCount: Counter = Counter()) {
        StubURLProtocol.register(host: "ca.gxu.edu.cn") { request in
            let path = request.url!.path
            if path.hasSuffix("getPubKey") { return reply(request, pubKey) }
            if path.hasSuffix("getKaptchaStatus") { return reply(request, kaptcha) }
            if path == "/zfca/login" {
                if request.httpMethod == "POST" {
                    postCount.increment()
                    return loginSucceeds ? reply(request, status: 302, headers: ["Location": "/zfca/index"], "") : reply(request, loginPage)
                }
                return reply(request, loginPage)
            }
            if path == "/zfca/index" { return reply(request, "<html><title>统一身份认证-主页</title></html>") }
            if path == "/zfim/application/home/getYyfz.zf" {
                let hit = tokenHits.increment()
                if !tokenCheckWorks { return reply(request, loginPage) }
                return hit == 1
                    ? reply(request, status: 302, headers: ["Location": "http://ca.gxu.edu.cn:81/zfim/system/login/login.zf?ticket=ST-1"], "")
                    : reply(request, tokenCheckBody.value)
            }
            if path == "/zfim/system/login/login.zf" {
                return reply(request, status: 302, headers: ["Location": "/zfim/application/home/getYyfz.zf"], "")
            }
            return reply(request, status: 404, "")
        }
    }

    @Test func loginSucceedsWhenTheTokenCheckNeedsToFollowRedirects() async throws {
        registerCAFlow()
        try await makeSession().login(username: "2025001", password: "pw")
    }

    @Test func testTokenFollowsTheCASRedirectChain() async throws {
        registerCAFlow()
        #expect(try await makeSession().testToken())
    }

    @Test func tokenCheckLandingOnTheLoginPageMeansNotLoggedIn() async throws {
        registerCAFlow(tokenCheckWorks: false)
        #expect(try await makeSession().testToken() == false)
        do { try await makeSession().login(username: "2025001", password: "pw"); Issue.record("应该失败") } catch {
            let message = (error as? GxuError)?.userMessage ?? ""
            #expect(message.contains("校验接口"))
            #expect(!message.contains("账号和密码"))
        }
    }

    @Test func captchaRequiredIsReportedAndNothingIsSubmitted() async {
        let posts = Counter()
        registerCAFlow(kaptcha: "true", postCount: posts)
        do { try await makeSession().login(username: "2025001", password: "pw"); Issue.record("应该失败") } catch {
            let message = (error as? GxuError)?.userMessage ?? ""
            #expect(message.contains("验证码"))
            #expect(!message.contains("账号或密码"))
        }
        #expect(posts.value == 0)
    }

    @Test func forbiddenAndServerErrorsAreNotBlamedOnThePassword() async {
        for (status, expected) in [(403, "校园网"), (503, "暂时不可用")] {
            StubURLProtocol.register(host: "ca.gxu.edu.cn") { request in
                request.url!.path.hasSuffix("getPubKey") ? reply(request, pubKey) : reply(request, status: status, "<html>x</html>")
            }
            do { try await makeSession().login(username: "2025001", password: "pw"); Issue.record("应该失败") } catch {
                let message = (error as? GxuError)?.userMessage ?? ""
                #expect(message.contains(expected), "HTTP \(status) → \(message)")
                #expect(!message.contains("账号"), "HTTP \(status) 不该说账号：\(message)")
            }
        }
    }

    @Test func failuresAreWrittenToTheDiagnosticLogWithoutSecrets() async {
        registerCAFlow(tokenCheckWorks: false)
        _ = try? await makeSession().login(username: "2025001", password: "S3cretPw")
        let log = ErrorLog.shared.contents()
        #expect(log.contains("统一认证 校验接口"))
        #expect(!log.contains("S3cretPw"))
    }

    @Test func extractsTheServerErrorTextFromTheLoginPage() {
        let html = Data("<p class=\"error text-left\" id=\"errormsg\">\n  用户名或密码错误 \n</p>".utf8)
        #expect(UnifiedAuthSession.pageErrorMessage(in: html) == "用户名或密码错误")
        #expect(UnifiedAuthSession.pageErrorMessage(in: Data("<p id=\"errormsg\">\n\t</p>".utf8)) == "")
        #expect(UnifiedAuthSession.pageErrorMessage(in: Data("<html/>".utf8)) == "")
    }

    @MainActor
    @Test func unifiedStateFollowsOnlyExplicitRejections() async {
        func center() -> (AccountCenter, UnifiedAuthSession) {
            let creds = InMemoryCredentialStore([.unified: Credential(username: "2025001", password: "pw")])
            let unified = UnifiedAuthSession(credentials: creds, configuration: StubURLProtocol.makeConfiguration())
            let client = BackendClient(session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
            return (AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: client), unified: unified), unified)
        }
        func settle() async { try? await Task.sleep(for: .milliseconds(300)) }

        StubURLProtocol.register(host: "ca.gxu.edu.cn") { request in
            request.url!.path.hasSuffix("getPubKey") ? reply(request, pubKey) : reply(request, status: 403, "<html/>")
        }
        let (blocked, blockedSession) = center()
        _ = try? await blockedSession.loginPEC()
        await settle()
        #expect(blocked.states[.unified] == .authenticated)

        registerCAFlow(kaptcha: "true")
        let (captcha, captchaSession) = center()
        _ = try? await captchaSession.loginPEC()
        await settle()
        #expect(captcha.states[.unified] == .authenticated)

        StubURLProtocol.register(host: "ca.gxu.edu.cn") { request in
            let path = request.url!.path
            if path.hasSuffix("getPubKey") { return reply(request, pubKey) }
            if path.hasSuffix("getKaptchaStatus") { return reply(request, "false") }
            let page = loginPage.replacingOccurrences(of: "</form>", with: "<p class=\"error text-left\" id=\"errormsg\">用户名或密码错误</p></form>")
            return reply(request, page)
        }
        let (rejected, rejectedSession) = center()
        _ = try? await rejectedSession.loginPEC()
        await settle()
        #expect(rejected.states[.unified] == .needsRelogin)
        #expect(rejected.states[.unified]?.displayText == "需要重新登录")
    }

    @MainActor
    @Test func lateServiceRejectionDoesNotSignOutReplacementAccount() async throws {
        defer { DeferredUnifiedRejection.release() }
        StubURLProtocol.register(host: "ca.gxu.edu.cn") { request in
            let path = request.url!.path
            if path.hasSuffix("getPubKey") { return reply(request, pubKey) }
            if path.hasSuffix("getKaptchaStatus") { return reply(request, "false") }
            if path.hasSuffix("getYyfz.zf") { return reply(request, "[]") }
            if path.hasSuffix("logout") { return reply(request, "<html>logout</html>") }
            if request.httpMethod == "POST" { return reply(request, "<html>success</html>") }
            return reply(request, loginPage)
        }
        let creds = InMemoryCredentialStore([.unified: Credential(username: "A", password: "fake-A")])
        let configuration = StubURLProtocol.makeConfiguration()
        configuration.protocolClasses = [DeferredUnifiedRejection.self, StubURLProtocol.self]
        let unified = UnifiedAuthSession(credentials: creds, configuration: configuration)
        let transport = BackendClient(session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
        let accounts = AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: transport), unified: unified)
        let stale = Task { try await unified.loginPEC() }
        defer { stale.cancel() }
        try await DeferredUnifiedRejection.waitForRequest()
        await accounts.logout(.unified)
        try await accounts.login(.unified, username: "B", password: "fake-B")
        DeferredUnifiedRejection.release()
        await #expect(throws: CancellationError.self) { try await stale.value }
        #expect(accounts.savedUsername(.unified) == "B")
        #expect(accounts.states[.unified] == .authenticated)
    }

    @Test func tokenCheckAcceptsAJSONArrayLikeTheRealResponse() async throws {
        tokenCheckBody.value = TokenCheckBody.realShape
        registerCAFlow()
        try await makeSession().login(username: "2025001", password: "pw")
    }

    @Test func tokenCheckAcceptsAJSONObjectToo() async throws {
        defer { tokenCheckBody.value = TokenCheckBody.realShape }
        tokenCheckBody.value = #"{"apps":[]}"#
        registerCAFlow()
        #expect(try await makeSession().testToken())
    }

    @Test func tokenCheckStillRejectsHTMLAndScalars() {
        #expect(UnifiedAuthSession.isJSONContainer(Data("[]".utf8)))
        #expect(UnifiedAuthSession.isJSONContainer(Data("{}".utf8)))
        #expect(UnifiedAuthSession.isJSONContainer(Data(#"[{"a":1}]"#.utf8)))
        #expect(!UnifiedAuthSession.isJSONContainer(Data("<html>login</html>".utf8)))
        #expect(!UnifiedAuthSession.isJSONContainer(Data(#""just a string""#.utf8)))
        #expect(!UnifiedAuthSession.isJSONContainer(Data("42".utf8)))
        #expect(!UnifiedAuthSession.isJSONContainer(Data()))
    }
}
