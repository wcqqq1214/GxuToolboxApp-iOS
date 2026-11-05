import Foundation
import GxuFoundation
import GxuTestSupport
import Synchronization
import Testing
@testable import GxuAuth

private let pubKey = #"{"modulus":"a170b33839263059f28c105d1fb17c2390c192cfd3ac94af0f21ddb66cad4a268d116ece1738f7d93d9c172411e20b8f6b0d549b6f03675a1600a35a099950d836f675cc81e74ef5e8e25d940ed904759531985d5d9dc9f81818e811892f902bd23f0824128b2f330c5c7fd0a6a3a4506513270e269e0d37f2a74de452e6b439","exponent":"10001"}"#
private let loginPage = #"<form id="fm1" action="/zfca/login" method="post"><input type="hidden" name="execution" value="abc-123_XYZ"/></form>"#

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

/// 这些测试都用固定域名（ca / xlzxms），合并成一个串行测试，避免并行互相覆盖 handler。
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
        #expect(!body.contains("password=pw"))   // 密码必须是加密后的
    }

    @Test func wrongPasswordReturnsLoginPageAndThrows() async {
        StubURLProtocol.register(host: "ca.gxu.edu.cn") { request in
            request.url!.path.hasSuffix("getPubKey") ? reply(request, pubKey) : reply(request, loginPage)
        }
        let session = makeSession()
        await #expect(throws: GxuError.invalidData("统一认证账号或密码错误")) {
            try await session.loginPEC()
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
}
