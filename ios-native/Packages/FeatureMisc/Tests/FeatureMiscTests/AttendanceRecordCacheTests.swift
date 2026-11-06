import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureMisc

@MainActor @Suite struct AttendanceRecordCacheTests {
    private func services(_ backend: any BackendAPI, studentId: String? = "2025000001", state: AuthState = .authenticated, shared: InMemorySharedStore = InMemorySharedStore()) -> AppServices {
        let p = AppServices.preview()
        let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
        let creds = InMemoryCredentialStore()
        let accounts = AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: client), states: [.attendance: state], studentId: studentId)
        return AppServices(backend: backend, database: p.database, shared: shared, accounts: accounts)
    }

    private func body(_ course: String) -> Data {
        Data(#"{"code":200,"data":{"items":[{"date":"2025-11-03","courseName":"\#(course)","periodRange":"1,2","periodLabel":"第1-2节","statusCode":2,"statusName":"迟到"}]}}"#.utf8)
    }

    @Test func viewModelLoadWritesCacheForThatStudentAndTerm() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /attendance/v2/personal", json: body("高数"))
        let s = services(mock)
        let m = AttendanceViewModel(services: s)
        m.isReady = true
        m.selection = .init(year: 2025, term: 1)
        await m.load()
        let cached = AttendanceRecordCache.cached(store: s.shared, studentId: "2025000001", year: 2025, term: 1)
        #expect(cached.count == 1 && cached[0].courseName == "高数" && cached[0].periodRange == "1,2" && cached[0].statusCode == 2)
        #expect(cached[0].periodText == "第1-2节" && cached[0].statusName == "迟到")
        #expect(AttendanceRecordCache.cached(store: s.shared, studentId: "2025000002", year: 2025, term: 1).isEmpty)   // 别的账号
        #expect(AttendanceRecordCache.cached(store: s.shared, studentId: "2025000001", year: 2025, term: 2).isEmpty)   // 别的学期
        #expect(AttendanceRecordCache.cached(store: s.shared, studentId: nil, year: 2025, term: 1).isEmpty)
    }

    @Test func silentRefreshKeepsCacheOnFailure() async {
        let shared = InMemorySharedStore()
        let ok = MockBackendAPI()
        ok.stub("GET /attendance/v2/personal", json: body("高数"))
        let first = await AttendanceRecordCache.refresh(services: services(ok, shared: shared), year: 2025, term: 1)
        #expect(first.map(\.courseName) == ["高数"])

        let failing = MockBackendAPI()
        failing.stub("GET /attendance/v2/personal", error: .network("boom"))
        let second = await AttendanceRecordCache.refresh(services: services(failing, shared: shared), year: 2025, term: 1)
        #expect(second.map(\.courseName) == ["高数"])   // 失败：保留缓存，不抛错
    }

    @Test func refreshDoesNothingWhenNotAuthenticated() async {
        let mock = MockBackendAPI()
        mock.stub("GET /attendance/v2/personal", json: body("高数"))
        let s = services(mock, state: .signedOut)
        #expect(await AttendanceRecordCache.refresh(services: s, year: 2025, term: 1).isEmpty)
        #expect(mock.calls.isEmpty)
    }
}
