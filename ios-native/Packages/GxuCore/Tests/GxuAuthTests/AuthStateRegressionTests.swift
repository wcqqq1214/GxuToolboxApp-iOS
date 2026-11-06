import Foundation
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Testing
@testable import GxuAuth

/// 账号状态前后矛盾（首页「已退出」、详情页「已登录」）的回归测试。
/// 规则：有保存的账号 = 已登录（会话缺失、断网、超时、5xx 都不改）；服务器明确拒绝 = 需要重新登录；主动退出 = 未登录。
@MainActor
struct AuthStateRegressionTests {
    private func make(host: String, credentials: [AuthSystem: Credential] = [.jw: Credential(username: "9", password: "p")])
        -> (AccountCenter, JwSessionManager, InMemoryCredentialStore) {
        let store = InMemoryCredentialStore(credentials)
        let client = BackendClient(baseURL: URL(string: "http://\(host)")!, session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
        let jw = JwSessionManager(credentials: store, transport: client)
        return (AccountCenter(credentials: store, jw: jw), jw, store)
    }

    /// 注册假服务并统计请求次数（静默续期在并行跑很多测试时可能晚一点才发出请求，所以按「请求真的发生了」来等，而不是固定延时）
    private func serve(_ host: String, _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) -> Counter {
        let hits = Counter()
        StubURLProtocol.register(host: host) { request in
            hits.increment()
            return try handler(request)
        }
        return hits
    }

    /// 等到至少来过一次请求（最多 5 秒），再多等一会儿让结果落到状态上
    private func settle(_ hits: Counter) async {
        for _ in 0..<100 where hits.value == 0 { try? await Task.sleep(for: .milliseconds(50)) }
        try? await Task.sleep(for: .milliseconds(300))
    }

    @Test func offlineSilentRenewDoesNotChangeTheState() async {
        let host = "as-\(UUID().uuidString).test"
        let hits = serve(host) { _ in throw URLError(.notConnectedToInternet) }
        let (center, jw, _) = make(host: host)
        #expect(center.states[.jw] == .authenticated)       // 启动时没有 Cookie 也是已登录，不是「已退出」
        await settle(hits)
        #expect(center.states[.jw] == .authenticated)       // 断网续期失败，状态不变
        #expect(center.states[.jw]?.displayText == "已登录")
        #expect(!jw.hasSession())
    }

    @Test func timeoutsAndServerErrorsDoNotChangeTheState() async {
        for failure in [URLError(.timedOut)] as [any Error] {
            let host = "as-\(UUID().uuidString).test"
            let hits = serve(host) { _ in throw failure }
            let (center, _, _) = make(host: host)
            await settle(hits)
            #expect(center.states[.jw] == .authenticated)
        }
        for status in [500, 502, 503, 403] {
            let host = "as-\(UUID().uuidString).test"
            let hits = serve(host) { respond($0, status: status) }
            let (center, _, _) = make(host: host)
            await settle(hits)
            #expect(center.states[.jw] == .authenticated, "HTTP \(status) 不该改变登录状态")
        }
    }

    @Test func explicitRejectionBecomesNeedsRelogin() async throws {
        let host = "as-\(UUID().uuidString).test"
        let hits = serve(host) { respond($0, status: 401, #"{"code":401,"message":"账号或密码错误，登录失败"}"#) }
        let (center, _, store) = make(host: host)
        await settle(hits)
        #expect(center.states[.jw] == .signedOut)
        #expect(center.states[.jw]?.displayText == "需要重新登录")
        #expect(center.states[.jw]?.displayText.contains("已退出") == false)
        #expect(center.states[.jw]?.showsLoginForm == true)
        #expect(center.studentId == "9")                     // 账号还在，详情页可以预填
        #expect(store.load(.jw)?.username == "9")
        await #expect(throws: GxuError.sessionExpired(.jw)) { try await center.ensureAuthenticated(.jw) }   // 不再自动重试
    }

    /// 回归：后端 / 教务上游故障也会返回 401（例如「无法获取初始登录cookie」），那不是账号密码的问题，不能变成「需要重新登录」
    @Test func upstreamFailureReturning401DoesNotChangeTheStateAndIsNotBlamedOnThePassword() async throws {
        let host = "as-\(UUID().uuidString).test"
        let hits = serve(host) { respond($0, status: 401, #"{"code":401,"message":"无法获取初始登录cookie","data":null}"#) }
        let (center, _, _) = make(host: host)
        await settle(hits)
        #expect(center.states[.jw] == .authenticated)
        #expect(center.states[.jw]?.displayText == "已登录")
        // 手动登录遇到同样的故障：报错文案如实说是服务问题，状态不变
        do { try await center.login(.jw, username: "9", password: "p"); Issue.record("应该失败") } catch {
            let message = (error as? GxuError)?.userMessage ?? ""
            #expect(message.contains("暂时不可用") && message.contains("无法获取初始登录cookie"))
            #expect(message.contains("不是账号密码的问题"))
            #expect(!(error as? GxuError)!.isCredentialRejection)
        }
        #expect(center.states[.jw] == .authenticated)
        #expect(ErrorLog.shared.contents().contains("教务登录：HTTP 401，但不是账号密码错误"))
    }

    @Test func onlyMessagesThatSayTheCredentialsAreWrongCountAsRejections() {
        for message in ["账号或密码错误，登录失败", "用户名或密码错误", "密码不正确", "账号不存在"] {
            #expect(JwSessionManager.isCredentialRejectionMessage(message), "应该算拒绝：\(message)")
        }
        for message in ["无法获取初始登录cookie", "登录态过期，请重新登录", "服务异常", "", nil] as [String?] {
            #expect(!JwSessionManager.isCredentialRejectionMessage(message), "不该算拒绝：\(message ?? "nil")")
        }
    }

    @Test func loggingInAgainAfterRejectionRestoresAuthenticated() async throws {
        let host = "as-\(UUID().uuidString).test"
        let accept = Counter()
        let hits = serve(host) { request in
            accept.value == 0
                ? respond(request, status: 401, #"{"message":"账号或密码错误，登录失败"}"#)
                : respond(request, status: 201, headers: ["Set-Cookie": "JSESSIONID=a, route=b"])
        }
        let (center, jw, _) = make(host: host)
        await settle(hits)
        #expect(center.states[.jw] == .signedOut)
        accept.value = 1
        try await center.login(.jw, username: "9", password: "new")
        #expect(center.states[.jw] == .authenticated)
        #expect(jw.hasSession())
    }

    @Test func userLogoutDuringTheSilentRenewIsNotRevived() async throws {
        let host = "as-\(UUID().uuidString).test"
        let hits = serve(host) { request in
            Thread.sleep(forTimeInterval: 0.6)
            return respond(request, status: 201, headers: ["Set-Cookie": "JSESSIONID=a, route=b"])
        }
        let (center, jw, store) = make(host: host)
        for _ in 0..<100 where hits.value == 0 { try await Task.sleep(for: .milliseconds(50)) }   // 登录请求已经在路上
        await center.logout(.jw)
        try await Task.sleep(for: .milliseconds(900))
        #expect(center.states[.jw] == .noAccount)
        #expect(center.states[.jw]?.displayText == "未登录")
        #expect(!jw.hasSession())
        #expect(store.load(.jw) == nil && center.studentId == nil)
    }

    @Test func rejectionAfterLogoutDoesNotBringTheStateBack() async throws {
        let host = "as-\(UUID().uuidString).test"
        let hits = serve(host) { request in
            Thread.sleep(forTimeInterval: 0.5)
            return respond(request, status: 401, #"{"message":"账号或密码错误，登录失败"}"#)
        }
        let (center, _, _) = make(host: host)
        for _ in 0..<100 where hits.value == 0 { try await Task.sleep(for: .milliseconds(50)) }
        await center.logout(.jw)
        try await Task.sleep(for: .milliseconds(800))
        #expect(center.states[.jw] == .noAccount)             // 迟到的「被拒绝」也不能把它改成需要重新登录
    }

    @Test func noAccountIsLoggedOutAndShowsTheLoginForm() {
        let (center, _, _) = make(host: "as-\(UUID().uuidString).test", credentials: [:])
        #expect(center.states[.jw] == .noAccount)
        #expect(center.states[.jw]?.displayText == "未登录")
        #expect(center.states[.jw]?.showsLoginForm == true)
    }

    @Test func displayTextAndLoginFormAreDerivedFromTheSameState() {
        let all: [(AuthState, String, Bool)] = [(.noAccount, "未登录", true), (.authenticated, "已登录", false), (.signedOut, "需要重新登录", true)]
        for (state, text, form) in all {
            #expect(state.displayText == text)
            #expect(state.showsLoginForm == form)
        }
    }

    @Test func attendanceWithoutTokenButWithAccountNeedsRelogin() {
        let store = InMemoryCredentialStore([.attendance: Credential(username: "a", password: "p")])
        let client = BackendClient(session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
        let attendance = AttendanceSession(transport: client, tokens: InMemoryTokenStore(), defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let center = AccountCenter(credentials: store, jw: JwSessionManager(credentials: store, transport: client), attendance: attendance)
        #expect(center.states[.attendance] == .signedOut)     // 不能静默续期（要验证码），所以是「需要重新登录」
        #expect(center.states[.attendance]?.displayText == "需要重新登录")
    }
}

private func respond(_ request: URLRequest, status: Int, headers: [String: String] = [:], _ body: String = "{}") -> (HTTPURLResponse, Data) {
    (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!, Data(body.utf8))
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0
    var value: Int { get { lock.withLock { storage } } set { lock.withLock { storage = newValue } } }
    func increment() { lock.withLock { storage += 1 } }
}
