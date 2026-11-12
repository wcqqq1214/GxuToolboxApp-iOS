import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import ScheduleKit
import Testing
@testable import FeatureCampus

private actor Gate {
    var open = false
    var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async { if open { return }; await withCheckedContinuation { waiters.append($0) } }
    func release() { open = true; waiters.forEach { $0.resume() }; waiters = [] }
}

private final class GatedBackend: BackendAPI, @unchecked Sendable {
    let wrapped: MockBackendAPI
    let gate = Gate()
    let lock = NSLock()
    var scheduleCalls = 0
    init(_ w: MockBackendAPI) { wrapped = w }
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        if path == "/jw/schedule/class-schedule" {
            let n = lock.withLock { scheduleCalls += 1; return scheduleCalls }
            if n <= 4 { await gate.wait() }
        }
        return try await wrapped.get(path, query: query, auth: auth, as: type)
    }
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        try await wrapped.post(path, body: body, auth: auth, as: type)
    }
}

struct FullScheduleScanTests {
    @MainActor @Test func supersededScanCannotUpdateCurrentProgressOrResults() async throws {
        let mock = MockBackendAPI()
        let dir = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        func fx(_ n: String) throws -> Data { try Data(contentsOf: dir.appendingPathComponent(n + ".json")) }
        mock.stub("GET /jw/schedule/schools", json: try fx("campus-schools"))
        mock.stub("GET /jw/schedule/majors", json: try fx("campus-majors"))
        mock.stub("GET /jw/schedule/class-schedules", json: try fx("campus-classes"))
        mock.stub("GET /jw/schedule/class-schedule", json: try fx("campus-class-schedule"))
        let gated = GatedBackend(mock)
        let services = AppServices.preview(backend: mock)
        let services2 = AppServices(backend: gated, database: services.database, shared: services.shared, accounts: services.accounts)
        let model = FullScheduleModel()
        await model.start(services: services2, context: CampusContext())
        model.term = AcademicTerm(year: 2031, term: 1)
        model.schoolId = "30100"
        model.moment = ClassMoment(week: 1, weekday: 1, period: 1)
        model.run()
        try await Task.sleep(for: .milliseconds(500))
        model.moment = ClassMoment(week: 1, weekday: 2, period: 1)
        model.run()
        try await Task.sleep(for: .milliseconds(1500))
        await gated.gate.release()
        try await Task.sleep(for: .milliseconds(1500))
        #expect(model.checked <= model.total)
        #expect(model.results.isEmpty)
    }

    @Test func concurrentRequestsForSameClassShareOneFetch() async throws {
        let mock = MockBackendAPI()
        let dir = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        mock.stub("GET /jw/schedule/class-schedule", json: try Data(contentsOf: dir.appendingPathComponent("campus-class-schedule.json")))
        let counting = GatedBackend(mock)
        let api = CampusAPI(backend: counting)
        let cache = ClassScheduleCache()
        let t = AcademicTerm(year: 2032, term: 1)
        async let a = cache.schedule(term: t, of: .sample, api: api)
        async let b = cache.schedule(term: t, of: .sample, api: api)
        try await Task.sleep(for: .milliseconds(300))
        await counting.gate.release()
        _ = try await (a, b)
        #expect(counting.scheduleCalls == 1)
    }
}
