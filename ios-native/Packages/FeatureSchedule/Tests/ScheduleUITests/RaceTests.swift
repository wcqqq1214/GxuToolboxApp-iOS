import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import ScheduleKit
import Synchronization
import Testing
@testable import ScheduleUI

/// 第 1 次课表请求被卡住，直到 release；之后的请求立刻返回。课程名带请求的学年，便于判断数据来自哪个学期。
final class GatedBackend: BackendAPI, @unchecked Sendable {
    private struct State { var released = false; var scheduleQueries: [String] = []; var gateNext = 1 }
    private let state = Mutex(State())
    init(gate: Int) { state.withLock { $0.gateNext = gate } }
    func release() { state.withLock { $0.released = true } }
    var scheduleQueries: [String] { state.withLock { $0.scheduleQueries } }

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let json: Data
        if path == "/jw/profile/startDay" {
            let days = [TermStartDay(year: 2026, term: 1, day: "2026-09-07", week: 20, isCurrent: true),
                        TermStartDay(year: 2025, term: 1, day: "2025-09-08", week: 20)]
            json = try JSONEncoder().encode(["data": days])
        } else if path == "/jw/schedule/personal" {
            let (n, shouldGate) = state.withLock { s -> (Int, Bool) in
                s.scheduleQueries.append(query["year"] ?? "?"); return (s.scheduleQueries.count, s.scheduleQueries.count == s.gateNext)
            }
            _ = n
            if shouldGate { while !state.withLock({ $0.released }) { try await Task.sleep(for: .milliseconds(10)) } }
            let c = TheoryCourse(venueName: "", sectionRange: "1-2", begin: 1, end: 2, courseName: "Y\(query["year"] ?? "?")#\(n)", weeks: Array(1...20), teacher: "", weekday: 1)
            json = try JSONEncoder().encode(["data": Schedule(theoryList: [c])])
        } else { throw GxuError.network("unstubbed \(path)") }
        return try JSONDecoder().decode(type, from: json)
    }
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("unstubbed")
    }
}

@MainActor
struct RaceTests {
    init() { URLProtocol.registerClass(StubURLProtocol.self) }   // 节假日接口：拦掉，不走真实网络

    private func waitUntil(_ cond: @MainActor () -> Bool) async {
        for _ in 0..<500 where !cond() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    /// 自动刷新还在途中，用户在标题菜单里换学期：旧学期的课表会被当成新学期的课表显示，新学期的请求被跳过。
    @Test func selectingTermDuringRefreshShowsOtherTermsSchedule() async throws {
        let backend = GatedBackend(gate: 1)
        let services = AppServices.preview(backend: MockBackendAPI(), features: [ScheduleKit.migrations], studentId: "A")
        let svc = AppServices(backend: backend, database: services.database, shared: services.shared, accounts: services.accounts)
        let model = ScheduleViewModel()
        let load = Task { await model.load(services: svc) }
        await waitUntil { backend.scheduleQueries.count == 1 }
        #expect(backend.scheduleQueries == ["2026"])           // 2026 秋的刷新在途
        await model.select(term: AcademicTerm(year: 2025, term: 1))
        backend.release()
        await load.value
        #expect(model.term == AcademicTerm(year: 2025, term: 1))
        #expect(model.schedule?.theoryList.map(\.courseName) != ["Y2026#1"])   // 期望：不是 2026 的课
        #expect(backend.scheduleQueries.contains("2025"))                      // 期望：请求过 2025
    }

    /// 刷新（下拉 / 回前台，不会随账号切换被取消）途中换账号：A 的课表写进 B 的界面，B 的刷新被 isRefreshing 挡掉。
    @Test func accountSwitchDuringRefreshLeaksPreviousStudent() async throws {
        let backend = GatedBackend(gate: 2)
        let a = AppServices.preview(backend: MockBackendAPI(), features: [ScheduleKit.migrations], studentId: "A")
        let b = AppServices.preview(backend: MockBackendAPI(), studentId: "B")
        let svcA = AppServices(backend: backend, database: a.database, shared: a.shared, accounts: a.accounts)
        let svcB = AppServices(backend: backend, database: a.database, shared: a.shared, accounts: b.accounts)
        let model = ScheduleViewModel()
        await model.load(services: svcA)                                   // 请求 #1：A 的课表
        let pull = Task { await model.refresh() }                          // 请求 #2：A 的下拉刷新，在途
        await waitUntil { backend.scheduleQueries.count == 2 }
        await model.load(services: svcB)                                   // 换成 B
        backend.release()
        await pull.value
        let names = model.schedule?.theoryList.map(\.courseName) ?? []
        // B 的界面只应显示 B 的请求（#3）的结果
        #expect(backend.scheduleQueries.count == 3)
        #expect(names == ["Y2026#3"])
    }
}
