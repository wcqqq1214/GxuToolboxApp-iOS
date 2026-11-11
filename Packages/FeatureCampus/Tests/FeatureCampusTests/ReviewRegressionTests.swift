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

private struct FakeEng2: EngTrainingClient { let data: Data; func scheduleTable() async throws -> Data { data } }
private struct FakePEC: PECClient { let data: Data; func ruleManage() async throws -> Data { data } }

struct ReviewRegressionTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Shanghai")!; return c }
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day))! }

    @MainActor @Test func staleRunMixesIntoNewRun() async throws {
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

    @Test func leapDay() {
        let r = EngTrainingParser.resolve("2月29日", now: d(2028, 12, 1), calendar: cal)!
        let c = cal.dateComponents([.year, .month, .day], from: r)
        #expect(c.month == 2 && c.day == 29)
        let bad = EngTrainingParser.resolve("2月30日", now: d(2026, 2, 1), calendar: cal)
        #expect(bad == nil)
    }

    @Test func duplicateDateHeaderBreaksRefresh() async throws {
        let raw = #"{"datas":[[{"startRow":2,"startCol":1,"colNumber":1,"content":"10月8日"},{"startRow":2,"startCol":2,"colNumber":1,"content":"10月8日"}]]}"#
        let db = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let repo = EngTrainingRepository(database: db, client: FakeEng2(data: Data(raw.utf8)))
        do { _ = try await repo.refresh(unifiedUsername: "A", now: d(2026, 10, 1)); print("DUP ok") } catch { print("DUP threw:", error) ; throw error }
    }

    @Test func emptyOrRenamedPayloadWipesCache() async throws {
        let db = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let good = #"{"datas":[[{"startRow":2,"startCol":1,"colNumber":1,"content":"10月8日"}]]}"#
        _ = try await EngTrainingRepository(database: db, client: FakeEng2(data: Data(good.utf8))).refresh(unifiedUsername: "A", now: d(2026, 10, 1))
        let shifted = #"{"datas":[[{"startRow":3,"startCol":1,"colNumber":1,"content":"10月8日"}]]}"#
        _ = try? await EngTrainingRepository(database: db, client: FakeEng2(data: Data(shifted.utf8))).refresh(unifiedUsername: "A", now: d(2026, 10, 1))
        let eng = await EngTrainingRepository(database: db, client: FakeEng2(data: Data())).cached(unifiedUsername: "A").count
        #expect(eng == 1)

        let goodPec = #"{"d":"{\"data\":[{\"id\":\"1\",\"skrq\":\"20261008\",\"xmmc\":\"x\"}]}"}"#
        _ = try await PhyExpRepository(database: db, client: FakePEC(data: Data(goodPec.utf8))).refresh(unifiedUsername: "A")
        let renamed = #"{"d":"{\"data\":[{\"id\":\"1\",\"rq\":\"20261008\",\"xmmc\":\"x\"}]}"}"#
        let r = try? await PhyExpRepository(database: db, client: FakePEC(data: Data(renamed.utf8))).refresh(unifiedUsername: "A")
        let phy = await PhyExpRepository(database: db, client: FakePEC(data: Data())).cached(unifiedUsername: "A").count
        #expect(phy == 1)
    }

    @Test func nullFieldsRenderAsNullString() throws {
        let raw = #"{"d":"{\"data\":[{\"id\":\"1\",\"skrq\":\"20261008\",\"xmmc\":null,\"kcmc\":\"大学物理实验\",\"fjbh\":null,\"sysmc\":\"实验室A\"}]}"}"#
        let e = try PhyExpParser.parse(Data(raw.utf8))[0]
        #expect(e.title == "大学物理实验")
        #expect(e.place == "实验室A")
        let nullDate = #"{"d":"{\"data\":[{\"id\":\"1\",\"skrq\":null,\"xmmc\":\"x\"}]}"}"#
        #expect(try PhyExpParser.parse(Data(nullDate.utf8)).isEmpty)
    }

    @Test func cacheDuplicateFetches() async throws {
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
