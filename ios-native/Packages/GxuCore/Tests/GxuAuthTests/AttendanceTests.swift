import Synchronization
import Foundation
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Testing
@testable import GxuAuth

private func json(_ request: URLRequest, status: Int = 200, _ body: String) -> (HTTPURLResponse, Data) {
    (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, Data(body.utf8))
}

private let loginOK = """
{"code":200,"message":"success","data":{"token":"tok-1","calendarId":2053,"userId":42}}
"""

@MainActor
private func make(host: String, tokens: InMemoryTokenStore = InMemoryTokenStore(), creds: InMemoryCredentialStore = InMemoryCredentialStore())
    -> (AccountCenter, AttendanceSession, BackendClient, InMemoryCredentialStore, InMemoryTokenStore) {
    let config = StubURLProtocol.makeConfiguration()
    let url = URL(string: "http://\(host)")!
    let plain = BackendClient(baseURL: url, session: BackendClient.makeSession(configuration: config))
    let jw = JwSessionManager(credentials: creds, transport: plain)
    let attendance = AttendanceSession(transport: plain, tokens: tokens, defaults: UserDefaults(suiteName: UUID().uuidString)!)
    let backend = BackendClient(
        baseURL: url, session: BackendClient.makeSession(configuration: config),
        renewer: SessionRenewers(jw: jw, attendance: attendance),
        tokenProvider: { $0 == .attendance ? attendance.token : nil }
    )
    return (AccountCenter(credentials: creds, jw: jw, attendance: attendance), attendance, backend, creds, tokens)
}

@MainActor
struct AttendanceTests {
    @Test func captchaDecodesDataURL() async throws {
        let host = "att-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { json($0, #"{"code":200,"data":{"imageUrl":"data:image/jpeg;base64,AAEC","challengeToken":"t1","text":"ab12"}}"#) }
        let (center, _, _, _, _) = make(host: host)
        let captcha = try await center.attendanceCaptcha()
        #expect(captcha.ticket == "t1")
        #expect(captcha.text == "ab12")
        #expect(captcha.imageData == Data([0, 1, 2]))
    }

    @Test func loginStoresTokenAndCredentialAndSendsTicket() async throws {
        let host = "att-\(UUID().uuidString).test"
        let seen = Mutex<String?>(nil)
        StubURLProtocol.register(host: host) { request in
            seen.withLock { $0 = request.httpBody.flatMap { String(decoding: $0, as: UTF8.self) } ?? request.httpBodyStream.map { s in
                s.open(); defer { s.close() }
                var data = Data(); var buf = [UInt8](repeating: 0, count: 1024)
                while s.hasBytesAvailable { let n = s.read(&buf, maxLength: 1024); if n <= 0 { break }; data.append(buf, count: n) }
                return String(decoding: data, as: UTF8.self)
            } }
            return json(request, loginOK)
        }
        let (center, attendance, _, creds, tokens) = make(host: host)
        try await center.loginAttendance(username: " 2025001 ", password: "pw", captcha: "abcd", ticket: "t1")
        #expect(center.states[.attendance] == .authenticated)
        #expect(tokens.load() == "tok-1")
        #expect(creds.load(.attendance) == Credential(username: "2025001", password: "pw"))
        #expect(attendance.loginInfo?.userId == 42 && attendance.loginInfo?.calendarId == 2053)
        let body = seen.withLock { $0 } ?? ""
        #expect(body.contains("\"ticket\":\"t1\"") && body.contains("\"captchaCode\":\"abcd\""))
    }

    @Test func wrongCaptchaSurfacesServerMessageAndStoresNothing() async {
        let host = "att-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { json($0, status: 400, #"{"code":400,"message":"验证码错误","data":null}"#) }
        let (center, _, _, creds, tokens) = make(host: host)
        await #expect(throws: GxuError.http(status: 400, message: "验证码错误")) {
            try await center.loginAttendance(username: "1", password: "2", captcha: "x", ticket: nil)
        }
        #expect(tokens.load() == nil)
        #expect(creds.load(.attendance) == nil)
        #expect(center.states[.attendance] == .noAccount)
    }

    @Test func requestsCarryTokenHeader() async throws {
        let host = "att-\(UUID().uuidString).test"
        let header = Mutex<String?>(nil)
        StubURLProtocol.register(host: host) { request in
            header.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            return json(request, #"{"code":200,"data":{"ok":true}}"#)
        }
        struct Ok: Decodable, Sendable { let ok: Bool }
        let (_, _, backend, _, _) = make(host: host, tokens: InMemoryTokenStore("abc"))
        _ = try await backend.getData("/attendance/index-data", auth: .attendance, as: Ok.self)
        #expect(header.withLock { $0 } == "Token abc")
    }

    @Test func unauthorizedClearsTokenAndMarksSignedOut() async throws {
        let host = "att-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { json($0, status: 401, #"{"code":401,"message":"考勤系统拒绝了该请求，请重新登录","data":null}"#) }
        struct Ok: Decodable, Sendable { let ok: Bool }
        let tokens = InMemoryTokenStore("old")
        let creds = InMemoryCredentialStore([.attendance: Credential(username: "1", password: "2")])
        let (center, _, backend, _, _) = make(host: host, tokens: tokens, creds: creds)
        #expect(center.states[.attendance] == .authenticated)
        await #expect(throws: GxuError.sessionExpired(.attendance)) {
            _ = try await backend.getData("/attendance/index-data", auth: .attendance, as: Ok.self)
        }
        try await Task.sleep(for: .milliseconds(100))
        #expect(tokens.load() == nil)
        #expect(center.states[.attendance] == .signedOut)
        await #expect(throws: GxuError.sessionExpired(.attendance)) { try await center.ensureAuthenticated(.attendance) }
    }

    @Test func logoutClearsEverything() async throws {
        let host = "att-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { json($0, loginOK) }
        let (center, attendance, _, creds, tokens) = make(host: host)
        try await center.loginAttendance(username: "1", password: "2", captcha: "x", ticket: nil)
        await center.logout(.attendance)
        #expect(tokens.load() == nil && creds.load(.attendance) == nil && attendance.loginInfo == nil)
        #expect(center.states[.attendance] == .noAccount)
    }
}
