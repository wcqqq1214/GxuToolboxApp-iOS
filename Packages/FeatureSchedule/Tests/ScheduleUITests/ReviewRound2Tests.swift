import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import ScheduleKit
import Testing
@testable import ScheduleUI

struct OfflineScheduleBackend: BackendAPI {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        if path == "/jw/profile/startDay" {
            let days = [TermStartDay(year: 2026, term: 1, day: "2026-09-07", week: 20)]
            return try JSONDecoder().decode(type, from: try JSONEncoder().encode(["data": days]))
        }
        throw GxuError.network("offline")
    }
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("unstubbed")
    }
}

struct TermsBackend: BackendAPI {
    var days: [TermStartDay]
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        if path == "/jw/profile/startDay" { return try JSONDecoder().decode(type, from: try JSONEncoder().encode(["data": days])) }
        if path == "/jw/schedule/personal" {
            let c = TheoryCourse(sectionRange: "1-2", begin: 1, end: 2, courseName: "NEW", weeks: Array(1...20), weekday: 1)
            return try JSONDecoder().decode(type, from: try JSONEncoder().encode(["data": Schedule(theoryList: [c])]))
        }
        throw GxuError.network("unstubbed")
    }
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("unstubbed")
    }
}

@MainActor
struct ReviewRound2Tests {
    init() { URLProtocol.registerClass(StubURLProtocol.self) }

    @Test func overlappingAccountLoadsKeepPreviousScheduleOutOfViewAndWidget() async throws {
        let a = AppServices.preview(backend: MockBackendAPI(), features: [ScheduleKit.migrations], studentId: "A")
        let b = AppServices.preview(backend: MockBackendAPI(), studentId: "B")
        let seed = ScheduleRepository(backend: GatedBackend(gate: 0), database: a.database)
        try await seed.refreshStartDays()
        try await seed.refreshSchedule(studentId: "A", term: AcademicTerm(year: 2026, term: 1))

        let off = OfflineScheduleBackend()
        let svcA = AppServices(backend: off, database: a.database, shared: a.shared, accounts: a.accounts)
        let svcB = AppServices(backend: off, database: a.database, shared: a.shared, accounts: b.accounts)
        let model = ScheduleViewModel()
        let first = Task { await model.load(services: svcA) }
        await Task.yield()
        await model.load(services: svcB)
        await first.value
        let names = model.schedule?.theoryList.map(\.courseName) ?? []
        let snap = svcB.shared.value(ScheduleKit.widgetSnapshotKey(studentId: "B"))
        #expect(names.isEmpty)
        #expect(snap?.next == nil && (snap?.today.isEmpty ?? true))
    }

    private func ymd(daysAgo: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    @Test func termRolloverDropsPreviousTermActivitiesFromView() async throws {
        let old = TermStartDay(year: 2025, term: 1, day: ymd(daysAgo: 400), week: 20)
        let new = TermStartDay(year: 2026, term: 1, day: ymd(daysAgo: 10), week: 20)
        let a = AppServices.preview(backend: MockBackendAPI(), features: [ScheduleKit.migrations], studentId: "A")
        let seed = ScheduleRepository(backend: TermsBackend(days: [old]), database: a.database)
        try await seed.refreshStartDays()
        try await seed.saveCustomActivity(CustomActivity(id: "act-old", name: "OLDTERM-ACT", weekday: 2, begin: 3, end: 4, weekFrom: 1, weekTo: 20),
                                          studentId: "A", term: AcademicTerm(year: 2025, term: 1))
        let svc = AppServices(backend: TermsBackend(days: [old, new]), database: a.database, shared: a.shared, accounts: a.accounts)
        let model = ScheduleViewModel()
        await model.load(services: svc)
        let shown = model.index.occurrences.map(\.course.courseName)
        #expect(model.term == AcademicTerm(year: 2026, term: 1))
        #expect(model.activities.isEmpty)
        #expect(!shown.contains("OLDTERM-ACT"))
    }
}
