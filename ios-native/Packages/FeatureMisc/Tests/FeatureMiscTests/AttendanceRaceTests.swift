import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureMisc

/// 按学期（calendarId）区分的假后端：可以让某个学期的请求挂起，再手动放行，用来复现"旧响应晚到"
final class AttendanceGateBackend: BackendAPI, @unchecked Sendable {
    private let lock = NSLock()
    private var cont: CheckedContinuation<Void, Never>?
    private var hangCal: String?
    private var failAfterRelease = false
    var arrived: Bool { lock.withLock { cont != nil } }
    func hang(calendarId: Int, thenFail: Bool = false) { lock.withLock { hangCal = String(calendarId); failAfterRelease = thenFail } }
    func release() { lock.withLock { let c = cont; cont = nil; return c }?.resume() }

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let cal = query["calendarId"] ?? ""
        if lock.withLock({ hangCal == cal }) {
            await withCheckedContinuation { c in lock.withLock { cont = c } }
            if lock.withLock({ failAfterRelease }) { throw GxuError.network("boom") }
        }
        let json = #"{"code":200,"data":{"items":[{"date":"2025-11-03","courseName":"CAL\#(cal)","periodRange":"1,2","statusCode":1}]}}"#
        return try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T { fatalError() }
}

@MainActor @Suite struct AttendanceRaceTests {
    private func model(_ backend: AttendanceGateBackend) -> AttendanceViewModel {
        let p = AppServices.preview()
        let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
        let creds = InMemoryCredentialStore()
        let accounts = AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: client), states: [.attendance: .authenticated], studentId: "1")
        let m = AttendanceViewModel(services: AppServices(backend: backend, database: p.database, shared: p.shared, accounts: accounts))
        m.isReady = true
        m.selection = .init(year: 2025, term: 1)
        return m
    }

    @Test func staleLoadDoesNotOverwriteNewerTerm() async throws {
        let b = AttendanceGateBackend()
        let m = model(b)
        await m.load()                                              // 2025 秋（calendarId 18）
        b.hang(calendarId: AttendanceCalendarID.id(year: 2025, term: 1))
        let stale = Task { await m.load() }                        // 下拉刷新：不会被 .task(id:) 取消
        while !b.arrived { await Task.yield() }
        m.selection = .init(year: 2025, term: 2)                   // 用户切到春季（calendarId 19）
        await m.load()
        b.release(); await stale.value
        #expect(m.records.map(\.courseName) == ["CAL19"])
    }

    @Test func staleFailureDoesNotShowErrorOverNewerSuccess() async throws {
        let b = AttendanceGateBackend()
        let m = model(b)
        await m.load()
        b.hang(calendarId: 18, thenFail: true)
        let stale = Task { await m.load() }
        while !b.arrived { await Task.yield() }
        m.selection = .init(year: 2025, term: 2)
        await m.load()
        b.release(); await stale.value
        #expect(m.records.map(\.courseName) == ["CAL19"])
        #expect(m.error == nil && !m.isLoading)
    }

    @Test func defaultsAndLoadingWork() async {
        let b = AttendanceGateBackend()
        let m = model(b)
        await m.load()
        #expect(m.records.count == 1 && m.error == nil && !m.isLoading && m.access == .ok)
    }

    @Test func signedOutAccountSeesLoginPrompt() async {
        let p = AppServices.preview()
        let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
        let creds = InMemoryCredentialStore()
        for (state, access) in [(AuthState?.none, AttendanceViewModel.Access.notLoggedIn), (.signedOut, .expired)] {
            var states: [AuthSystem: AuthState] = [:]
            if let state { states[.attendance] = state }
            let accounts = AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: client), states: states, studentId: "1")
            let m = AttendanceViewModel(services: AppServices(backend: AttendanceGateBackend(), database: p.database, shared: p.shared, accounts: accounts))
            m.isReady = true
            await m.load()
            #expect(m.access == access && m.records.isEmpty)
        }
    }
}
