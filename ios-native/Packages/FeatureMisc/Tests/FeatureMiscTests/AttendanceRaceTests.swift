import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureMisc

final class AttendanceGateBackend: BackendAPI, @unchecked Sendable {
    private let lock = NSLock()
    private var cont: CheckedContinuation<Void, Never>?
    private var hangCal: String?
    var arrived: Bool { lock.withLock { cont != nil } }
    func hang(_ cal: String) { lock.withLock { hangCal = cal } }
    func release() { lock.withLock { let c = cont; cont = nil; return c }?.resume() }
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let json: String
        if path == "/attendance/index-data" {
            json = #"{"data":{"code":600,"data":{"calendarList":[{"calendarId":1,"calendarName":"2025-1","firstWeekBegin":"2025-09-01","weekTotal":20,"isCurrent":1},{"calendarId":2,"calendarName":"2025-2","firstWeekBegin":"2026-03-01","weekTotal":20}]}}}"#
        } else {
            let cal = query["cal"] ?? ""
            if lock.withLock({ hangCal == cal }) { await withCheckedContinuation { c in lock.withLock { cont = c } } }
            json = #"{"data":{"code":600,"data":{"records":[{"day":"2025-11-03","courseName":"CAL\#(cal)","atdStateId":1}],"total_record":1,"total_page":1,"page_index":1}}}"#
        }
        return try JSONDecoder().decode(type, from: Data(json.utf8))
    }
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T { fatalError() }
}

@MainActor @Suite struct AttendanceRaceTests {
    @Test func staleLoadDoesNotOverwriteNewerCalendar() async throws {
        let p = AppServices.preview()
        let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
        let creds = InMemoryCredentialStore()
        let jw = JwSessionManager(credentials: creds, transport: client)
        let att = AccountCenter(credentials: creds, jw: jw, states: [.attendance: .authenticated], studentId: "1")
        let b = AttendanceGateBackend()
        let s = AppServices(backend: b, database: p.database, shared: p.shared, accounts: att)
        let m = AttendanceViewModel(services: s)
        await m.load()                       // calendars + current (id 1) records
        b.hang("1")
        let t = Task { await m.load() }      // pull-to-refresh on calendar 1 (not cancelled by .task(id:))
        while !b.arrived { await Task.yield() }
        m.calendarId = 2                     // user switches term
        await m.load()
        b.release(); await t.value
        #expect(m.records.map(\.courseName) == ["CAL2"])
    }
}

@Suite struct LenientNumberTests {
    @Test func hugeNumbersDoNotTrap() throws {
        let cal = try JSONDecoder().decode(AttendanceCalendar.self, from: Data(#"{"calendarId":1e30,"calendarName":"2025-1","firstWeekBegin":"2025-09-01","weekTotal":1e30,"isCurrent":-1e30}"#.utf8))
        #expect(cal.weekTotal == 20)   // 不能转成 Int 的数字按"缺失"处理，回退到默认值
        let page = try JSONDecoder().decode(AttendanceRecordPage.self, from: Data(#"{"records":[],"total_record":1e300,"total_page":-1e30,"page_index":1e19}"#.utf8))
        #expect(page.totalRecord == 0 && page.totalPage == 1 && page.pageIndex == 1)
    }
}

@Suite struct AttendanceDateTests {
    @Test func invalidDatesAreNotShifted() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        #expect(AttendanceDay.parse("2026-02-30", calendar: cal) == nil)
        #expect(AttendanceDay.parse("2026-13-01", calendar: cal) == nil)
        #expect(AttendanceDay.parse("2025-09-01 00:00:00", calendar: cal) != nil)
    }
}

@Suite struct AttendanceHostileScheduleTests {
    @Test func hugeConnectCountIsClampedNotTrapped() throws {
        let json = #"{"resTableRankList":[{"courses":[{},{"weekDay":"2025-09-01","subjectName":"X","connectCount":9223372036854775807}]},{"courses":[{},{}]},{"courses":[{},{}]}]}"#
        let courses = try JSONDecoder().decode(AttendanceScheduleTable.self, from: Data(json.utf8)).courses()
        #expect(courses.count == 1 && courses[0].firstPeriod == 1 && courses[0].lastPeriod == 3)   // 最多占到表的最后一行
        let last = try JSONDecoder().decode(AttendanceScheduleTable.self, from: Data(#"{"resTableRankList":[{"courses":[{},{"weekDay":"2025-09-01","subjectName":"Y","connectCount":5}]}]}"#.utf8)).courses()
        #expect(last.first?.lastPeriod == 1)   // 最后一行没有后续行可连
    }
}

@MainActor @Suite struct AttendanceStaleFailureTests {
    final class FailingGate: BackendAPI, @unchecked Sendable {
        private let lock = NSLock()
        private var cont: CheckedContinuation<Void, Never>?
        private var hangCal: String?
        var arrived: Bool { lock.withLock { cont != nil } }
        func hang(_ cal: String) { lock.withLock { hangCal = cal } }
        func release() { lock.withLock { let c = cont; cont = nil; return c }?.resume() }
        func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
            if path == "/attendance/index-data" {
                let json = #"{"data":{"code":600,"data":{"calendarList":[{"calendarId":1,"calendarName":"2025-1","firstWeekBegin":"2025-09-01","weekTotal":20,"isCurrent":1},{"calendarId":2,"calendarName":"2025-2","firstWeekBegin":"2026-03-01","weekTotal":20}]}}}"#
                return try JSONDecoder().decode(type, from: Data(json.utf8))
            }
            let cal = query["cal"] ?? ""
            if lock.withLock({ hangCal == cal }) {
                await withCheckedContinuation { c in lock.withLock { cont = c } }
                throw GxuError.network("boom")
            }
            let json = #"{"data":{"code":600,"data":{"records":[{"day":"2025-11-03","courseName":"CAL\#(cal)","atdStateId":1}],"total_record":1,"total_page":1,"page_index":1}}}"#
            return try JSONDecoder().decode(type, from: Data(json.utf8))
        }
        func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T { fatalError() }
    }

    @Test func staleFailureDoesNotShowErrorOverNewerSuccess() async throws {
        let p = AppServices.preview()
        let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
        let creds = InMemoryCredentialStore()
        let accounts = AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: client), states: [.attendance: .authenticated], studentId: "1")
        let gate = FailingGate()
        let m = AttendanceViewModel(services: AppServices(backend: gate, database: p.database, shared: p.shared, accounts: accounts))
        await m.load()
        gate.hang("1")
        let stale = Task { await m.load() }
        while !gate.arrived { await Task.yield() }
        m.calendarId = 2
        await m.load()
        gate.release(); await stale.value
        #expect(m.records.map(\.courseName) == ["CAL2"])
        #expect(m.error == nil)
        #expect(!m.isLoading)
    }
}
