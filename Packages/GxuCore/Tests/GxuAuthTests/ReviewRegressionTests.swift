import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Synchronization
import Testing
@testable import GxuAuth

/// 对抗审查（第 1 轮）里被证实的问题的回归测试。每个测试在修复前都会失败。
struct RedactionRegressionTests {
    @Test func commonSecretFormatsAreMasked() {
        let cases: [(input: String, secret: String)] = [
            (#"{"password":"S3cretPw"}"#, "S3cretPw"),
            (#"{"accessToken":"AAAtokenBBB"}"#, "AAAtokenBBB"),
            ("access_token=AAAtokenBBB", "AAAtokenBBB"),
            ("refreshToken=RRR123abc", "RRR123abc"),
            ("password=ab;cdLEAK1", "cdLEAK1"),
            ("password=ab,cdLEAK2", "cdLEAK2"),
            ("Cookie: JSESSIONID=aaa; route=LEAKROUTE; other=LEAKOTHER", "LEAKROUTE"),
            ("Set-Cookie: route=LEAKROUTE2; Path=/", "LEAKROUTE2"),
            ("密码：LEAKCN", "LEAKCN"),
            ("password: my LEAKSPACE pass", "LEAKSPACE"),
            ("手机 138-0013-8000 LEAKPHONE", "138-0013-8000"),
            ("手机 138 0013 8000", "0013"),
            ("Authorization: Bearer abc.def.ghi", "abc.def.ghi"),
        ]
        for (input, secret) in cases {
            let output = ErrorLog.redact(input)
            #expect(!output.contains(secret), "「\(input)」脱敏后仍含「\(secret)」：\(output)")
        }
    }

    @Test func ordinaryDiagnosticsAreKept() {
        #expect(ErrorLog.redact("GET /jw/exam → HTTP 500 (code 200)") == "GET /jw/exam → HTTP 500 (code 200)")
        #expect(ErrorLog.redact("network error -1009") == "network error -1009")
    }
}

struct QueryEncodingRegressionTests {
    @Test func plusAndReservedCharactersAreEncoded() {
        #expect(QueryString.encode(["q": "C++ a&b=c/d"]) == "q=C%2B%2B%20a%26b%3Dc%2Fd")
        #expect(QueryString.encode(["q": "王"]) == "q=%E7%8E%8B")
        #expect(QueryString.encode(["b": "2", "a": "1"]) == "a=1&b=2")   // 稳定顺序
    }

    @Test func backendClientSendsEncodedPlus() async throws {
        let host = "q-\(UUID().uuidString).test"
        let seen = Mutex("")
        StubURLProtocol.register(host: host) { request in
            seen.withLock { $0 = request.url!.absoluteString }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"data":1}"#.utf8))
        }
        let client = BackendClient(baseURL: URL(string: "http://\(host)")!, session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
        _ = try await client.getData("/x", query: ["q": "C++ a&b"], auth: nil, as: Int.self)
        #expect(seen.withLock { $0 }.hasSuffix("/x?q=C%2B%2B%20a%26b"))
    }
}

@MainActor
struct LogoutRaceRegressionTests {
    /// 静默重登的请求还在路上时用户退出：迟到的登录结果不能把已退出的账号写回（Cookie、已登录状态）
    @Test func logoutDuringSilentRenewStaysLoggedOut() async throws {
        let host = "race-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { request in
            Thread.sleep(forTimeInterval: 0.6)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Set-Cookie": "JSESSIONID=a, route=b"])!, Data("{}".utf8))
        }
        let store = InMemoryCredentialStore([.jw: Credential(username: "9", password: "p")])
        let client = BackendClient(baseURL: URL(string: "http://\(host)")!, session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
        let jw = JwSessionManager(credentials: store, transport: client)
        let center = AccountCenter(credentials: store, jw: jw)
        try await Task.sleep(for: .milliseconds(100))
        let renew = Task { try? await jw.renew(.jw) }
        try await Task.sleep(for: .milliseconds(200))
        await center.logout(.jw)
        await renew.value
        try await Task.sleep(for: .milliseconds(200))
        #expect(center.states[.jw] == .noAccount)
        #expect(!jw.hasSession())
        #expect(store.load(.jw) == nil)
        #expect(center.studentId == nil)
    }
}

@Suite(.serialized)
struct WjxtLogoutRegressionTests {
    private func makeCenter(_ creds: InMemoryCredentialStore, wjxt: WjxtSession) async -> AccountCenter {
        let client = BackendClient(session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
        return await AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: client), wjxt: wjxt)
    }

    private func sessionCookie() -> HTTPCookie {
        HTTPCookie(properties: [.name: "ASP.NET_SessionId", .value: "SESS1", .domain: "wjxt.gxu.edu.cn", .path: "/"])!
    }

    @MainActor @Test func logoutOAClearsWjxtSession() async {
        let creds = InMemoryCredentialStore([.oa: Credential(username: "idcard", password: "pw")])
        let wjxt = WjxtSession(credentials: creds, configuration: StubURLProtocol.makeConfiguration())
        wjxt.cookies.setCookie(sessionCookie())
        #expect(!wjxt.sessionCookies().isEmpty)
        let center = await makeCenter(creds, wjxt: wjxt)
        await center.logout(.oa)
        #expect(wjxt.sessionCookies().isEmpty)
    }
}

struct ProfileOverflowRegressionTests {
    @Test func academicYearsNeverTrapsOnAbsurdValues() {
        let huge = UserProfile(studentId: "1", name: "", college: "", major: "", className: "", enrollmentYear: 2022, studyYears: Int.max)
        #expect(huge.academicYears.count == 12)
        let wrap = UserProfile(studentId: "1", name: "", college: "", major: "", className: "", enrollmentYear: Int.max, studyYears: 4)
        #expect(wrap.academicYears.count == 4)
        let none = UserProfile(studentId: "1", name: "", college: "", major: "", className: "", enrollmentYear: 2022, studyYears: -5)
        #expect(none.academicYears == [2022])
    }

    @Test func repositoryRejectsAbsurdGradeAndStudyYears() async {
        let backend = MockBackendAPI()
        backend.stub("POST /jw/profile", json: #"{"code":200,"data":{"student_id":"1","name":"n","grade":"99999999999","study_years":"4"}}"#)
        let repo = ProfileRepository(backend: backend, shared: InMemorySharedStore())
        await #expect(throws: GxuError.invalidData("用户资料中的入学年份或学制异常")) { try await repo.load(studentId: "1") }
        backend.stub("POST /jw/profile", json: #"{"code":200,"data":{"student_id":"1","name":"n","grade":"2022","study_years":"999999"}}"#)
        await #expect(throws: GxuError.invalidData("用户资料中的入学年份或学制异常")) { try await repo.load(studentId: "1") }
        #expect(repo.cached(studentId: "1") == nil)   // 异常数据不能写进缓存
    }
}
