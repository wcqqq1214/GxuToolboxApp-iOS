import Foundation
import GxuStorage
import Testing
@testable import FeatureCampus

private struct FakeEngTraining: EngTrainingClient { let data: Data; func scheduleTable() async throws -> Data { data } }

struct EngTrainingRefreshTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Shanghai")!; return c }
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day))! }

    @Test func leapDay() {
        let r = EngTrainingParser.resolve("2月29日", now: d(2028, 12, 1), calendar: cal)!
        let c = cal.dateComponents([.year, .month, .day], from: r)
        #expect(c.month == 2 && c.day == 29)
        let bad = EngTrainingParser.resolve("2月30日", now: d(2026, 2, 1), calendar: cal)
        #expect(bad == nil)
    }

    @Test func refreshAcceptsDuplicateDateHeaders() async throws {
        let raw = #"{"datas":[[{"startRow":2,"startCol":1,"colNumber":1,"content":"10月8日"},{"startRow":2,"startCol":2,"colNumber":1,"content":"10月8日"}]]}"#
        let db = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let repo = EngTrainingRepository(database: db, client: FakeEngTraining(data: Data(raw.utf8)))
        _ = try await repo.refresh(unifiedUsername: "A", now: d(2026, 10, 1))
    }

    @Test func unexpectedPayloadKeepsCachedEntries() async throws {
        let db = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let good = #"{"datas":[[{"startRow":2,"startCol":1,"colNumber":1,"content":"10月8日"}]]}"#
        _ = try await EngTrainingRepository(database: db, client: FakeEngTraining(data: Data(good.utf8))).refresh(unifiedUsername: "A", now: d(2026, 10, 1))
        let shifted = #"{"datas":[[{"startRow":3,"startCol":1,"colNumber":1,"content":"10月8日"}]]}"#
        _ = try? await EngTrainingRepository(database: db, client: FakeEngTraining(data: Data(shifted.utf8))).refresh(unifiedUsername: "A", now: d(2026, 10, 1))
        let eng = await EngTrainingRepository(database: db, client: FakeEngTraining(data: Data())).cached(unifiedUsername: "A").count
        #expect(eng == 1)
    }
}
