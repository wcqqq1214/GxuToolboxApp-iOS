import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureCampus

private struct FakeEng: EngTrainingClient {
    let result: Result<Data, GxuError>
    func scheduleTable() async throws -> Data { try result.get() }
}

struct EngTrainingTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }
    private func now(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d))! }
    private func fixture() throws -> Data { try loadFixture("xlzxms-arrange", bundle: .module) }

    @Test func parsesDateRowAndMatchesExperimentByColumnSpan() throws {
        let days = try EngTrainingParser.parse(try fixture(), now: now(2026, 10, 1), calendar: calendar)
        #expect(days.map(\.dateText) == ["10月8日", "10月9日"])        // 无法识别的日期被丢弃
        #expect(days.map(\.name) == ["车工实训", "数控铣实训"])
        #expect(calendar.component(.year, from: days[0].date) == 2026)
    }

    @Test func missingExperimentBecomesEmptyName() throws {
        let raw = #"{"datas":[[{"startRow":2,"startCol":1,"colNumber":1,"content":"3月5日"}]]}"#
        let days = try EngTrainingParser.parse(Data(raw.utf8), now: now(2026, 3, 1), calendar: calendar)
        #expect(days.count == 1 && days[0].name.isEmpty)
    }

    @Test func yearIsInferredFromNearestDate() {
        // 12 月看 1 月的安排 → 明年；1 月看 12 月的安排 → 去年
        #expect(calendar.component(.year, from: EngTrainingParser.resolve("1月6日", now: now(2026, 12, 20), calendar: calendar)!) == 2027)
        #expect(calendar.component(.year, from: EngTrainingParser.resolve("12月28日", now: now(2027, 1, 3), calendar: calendar)!) == 2026)
        #expect(EngTrainingParser.resolve("无日期", now: now(2026, 1, 1), calendar: calendar) == nil)
    }

    @Test func rejectsGarbage() {
        #expect(throws: GxuError.self) { try EngTrainingParser.parse(Data("<html>".utf8)) }
        #expect(throws: GxuError.self) { try EngTrainingParser.parse(Data(#"{"datas":[]}"#.utf8)) }
    }

    @Test func repositoryIsolatesStudentsAndKeepsCacheOnFailure() async throws {
        let database = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let ok = EngTrainingRepository(database: database, client: FakeEng(result: .success(try fixture())))
        _ = try await ok.refresh(unifiedUsername: "A", now: now(2026, 10, 1))
        #expect(await ok.cached(unifiedUsername: "A").count == 2)
        #expect(await ok.cached(unifiedUsername: "B").isEmpty)
        let failing = EngTrainingRepository(database: database, client: FakeEng(result: .failure(.notLoggedIn(.unified))))
        await #expect(throws: GxuError.self) { try await failing.refresh(unifiedUsername: "A") }
        #expect(await failing.cached(unifiedUsername: "A").count == 2)
    }
}
