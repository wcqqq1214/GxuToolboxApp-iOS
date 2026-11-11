import Synchronization
import Foundation
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Testing
@testable import GxuAuth

private func makeHost() -> String { "auth-\(UUID().uuidString).test" }

private func stubLogin(host: String, status: Int = 200, cookies: [String] = ["JSESSIONID=abc123; Path=/", "route=r1; Path=/"]) {
    StubURLProtocol.register(host: host) { request in
        var headers = ["Content-Type": "application/json"]
        if !cookies.isEmpty { headers["Set-Cookie"] = cookies.joined(separator: ", ") }
        return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!, Data("{}".utf8))
    }
}

@MainActor
private func makeCenter(host: String, store: InMemoryCredentialStore = InMemoryCredentialStore()) -> (AccountCenter, JwSessionManager, BackendClient) {
    let client = BackendClient(baseURL: URL(string: "http://\(host)")!, session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
    let jw = JwSessionManager(credentials: store, transport: client)
    return (AccountCenter(credentials: store, jw: jw), jw, client)
}

@MainActor
struct AuthTests {
    @Test func startsWithNoAccount() {
        let (center, _, _) = makeCenter(host: makeHost())
        #expect(center.states[.jw] == .noAccount)
        #expect(center.studentId == nil)
    }

    @Test func loginStoresCredentialAndCookies() async throws {
        let host = makeHost()
        stubLogin(host: host)
        let store = InMemoryCredentialStore()
        let (center, jw, client) = makeCenter(host: host, store: store)
        try await center.login(.jw, username: " 2025001 ", password: "pw")
        #expect(center.states[.jw] == .authenticated)
        #expect(center.studentId == "2025001")
        #expect(store.load(.jw) == Credential(username: "2025001", password: "pw"))
        #expect(jw.hasSessionCookie())
        let backendCookies = client.cookieStorage.cookies(for: URL(string: "http://\(host)/")!) ?? []
        #expect(Set(backendCookies.map(\.name)) == ["JSESSIONID", "route"])
    }

    @Test func loginWithoutCookiesFailsAndStoresNothing() async {
        let host = makeHost()
        stubLogin(host: host, cookies: [])
        let store = InMemoryCredentialStore()
        let (center, _, _) = makeCenter(host: host, store: store)
        await #expect(throws: GxuError.invalidData("登录失败：未获取到教务会话")) {
            try await center.login(.jw, username: "1", password: "2")
        }
        #expect(store.load(.jw) == nil)
        #expect(center.states[.jw] == .noAccount)
    }

    @Test func loginHttpErrorSurfacesMessage() async {
        let host = makeHost()
        StubURLProtocol.register(host: host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!, Data(#"{"message":"账号或密码错误"}"#.utf8))
        }
        let (center, _, _) = makeCenter(host: host)
        await #expect(throws: GxuError.http(status: 400, message: "账号或密码错误")) {
            try await center.login(.jw, username: "1", password: "2")
        }
    }

    @Test func emptyInputIsRejected() async {
        let (center, _, _) = makeCenter(host: makeHost())
        await #expect(throws: GxuError.invalidData("请输入学号和密码")) {
            try await center.login(.jw, username: "", password: "")
        }
    }

    @Test func logoutClearsEverything() async throws {
        let host = makeHost()
        stubLogin(host: host)
        let store = InMemoryCredentialStore()
        let (center, jw, _) = makeCenter(host: host, store: store)
        try await center.login(.jw, username: "1", password: "2")
        await center.logout(.jw)
        #expect(center.states[.jw] == .noAccount)
        #expect(center.studentId == nil)
        #expect(store.load(.jw) == nil)
        #expect(!jw.hasSessionCookie())
    }

    @Test func requiringAuthenticatedStateWithoutAccountThrows() async {
        let (center, _, _) = makeCenter(host: makeHost())
        await #expect(throws: GxuError.notLoggedIn(.jw)) { try await center.requireAuthenticatedState(.jw) }
    }

    @Test func accountWithoutCookieStartsAuthenticatedAndRenewsSilently() async throws {
        let host = makeHost()
        stubLogin(host: host)
        let store = InMemoryCredentialStore([.jw: Credential(username: "9", password: "p")])
        let (center, jw, _) = makeCenter(host: host, store: store)
        #expect(center.states[.jw] == .authenticated)
        #expect(center.states[.jw]?.displayText == "已登录")
        for _ in 0..<50 where !jw.hasSessionCookie() { try await Task.sleep(for: .milliseconds(50)) }
        #expect(jw.hasSessionCookie())
        #expect(center.states[.jw] == .authenticated)
        try await center.requireAuthenticatedState(.jw)
    }

    @Test func concurrentRenewalsShareOneLogin() async throws {
        let host = makeHost()
        let hits = Mutex(0)
        StubURLProtocol.register(host: host) { request in
            hits.withLock { $0 += 1 }
            Thread.sleep(forTimeInterval: 0.2)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Set-Cookie": "JSESSIONID=a, route=b"])!, Data("{}".utf8))
        }
        let store = InMemoryCredentialStore([.jw: Credential(username: "9", password: "p")])
        let (_, jw, _) = makeCenter(host: host, store: store)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 { group.addTask { try await jw.renew(.jw) } }
            try await group.waitForAll()
        }
        #expect(hits.withLock { $0 } == 1)
    }

    @Test func credentialStoreRoundTrips() throws {
        let store = InMemoryCredentialStore()
        try store.save(Credential(username: "a", password: "b"), for: .jw)
        #expect(store.load(.jw)?.username == "a")
        store.delete(.jw)
        #expect(store.load(.jw) == nil)
    }

    @Test func mockBackendReturnsStubsAndRecordsCalls() async throws {
        struct Row: Decodable, Sendable, Equatable { let v: Int }
        let mock = MockBackendAPI()
        mock.stub("GET /jw/exam", json: #"{"data":[{"v":1}]}"#)
        mock.stub("GET /jw/score", error: .sessionExpired(.jw))
        let rows = try await mock.getData("/jw/exam", as: [Row].self)
        #expect(rows == [Row(v: 1)])
        await #expect(throws: GxuError.sessionExpired(.jw)) { try await mock.getData("/jw/score", as: [Row].self) }
        await #expect(throws: GxuError.self) { try await mock.getData("/unknown", as: [Row].self) }
        #expect(mock.calls == ["GET /jw/exam", "GET /jw/score", "GET /unknown"])
    }

    @Test func previewServicesAreAuthenticated() {
        let services = AppServices.preview(studentId: "123")
        #expect(services.accounts.states[.jw] == .authenticated)
        #expect(services.accounts.studentId == "123")
    }
}
