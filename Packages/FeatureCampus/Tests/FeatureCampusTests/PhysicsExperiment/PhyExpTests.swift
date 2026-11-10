import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureCampus

private struct FakePEC: PECClient {
    let result: Result<Data, GxuError>
    func ruleManage() async throws -> Data { try result.get() }
}

struct PhyExpTests {
    private func fixture() throws -> Data { try loadFixture("pec-ruleManage", bundle: .module) }

    @Test func parsesNestedResponseWithUppercaseKeys() throws {
        let list = try PhyExpParser.parse(try fixture())
        #expect(list.count == 2)                       // 没有日期的行被丢弃
        let first = try #require(list.first)
        #expect(first.title == "示波器的使用" && first.place == "理科楼101" && first.teacher == "教师甲")
        #expect(first.date() != nil)
    }

    @Test func fallsBackToCourseNameAndLab() {
        let e = PhyExperiment(id: "x", week: "", className: "", dateText: "20251001", timeText: "", courseName: "大学物理实验", experimentName: "", teacher: "", location: "", labName: "光学实验室")
        #expect(e.title == "大学物理实验" && e.place == "光学实验室")
    }

    @Test func rejectsGarbage() {
        #expect(throws: GxuError.self) { try PhyExpParser.parse(Data("<html>".utf8)) }
        #expect(throws: GxuError.self) { try PhyExpParser.parse(Data(#"{"d":"{\"nope\":1}"}"#.utf8)) }
    }

    @Test func repositoryCachesPerStudentAndKeepsCacheOnFailure() async throws {
        let database = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let ok = PhyExpRepository(database: database, client: FakePEC(result: .success(try fixture())))
        #expect(await ok.cached(unifiedUsername: "A").isEmpty)
        let fresh = try await ok.refresh(unifiedUsername: "A")
        #expect(fresh.count == 2)
        #expect(await ok.cached(unifiedUsername: "A").map(\.id) == ["E1", "E2"])
        #expect(await ok.cached(unifiedUsername: "B").isEmpty)           // 账号隔离

        let failing = PhyExpRepository(database: database, client: FakePEC(result: .failure(.notLoggedIn(.unified))))
        await #expect(throws: GxuError.self) { try await failing.refresh(unifiedUsername: "A") }
        #expect(await failing.cached(unifiedUsername: "A").count == 2)   // 失败保留旧缓存
    }

    @Test func refreshReplacesCancelledEntries() async throws {
        let database = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        _ = try await PhyExpRepository(database: database, client: FakePEC(result: .success(try fixture()))).refresh(unifiedUsername: "A")
        let smaller = #"{"d":"{\"data\":[{\"ID\":\"E2\",\"SKRQ\":\"20251015\",\"XMMC\":\"光栅衍射\"}]}"}"#
        let repo = PhyExpRepository(database: database, client: FakePEC(result: .success(Data(smaller.utf8))))
        _ = try await repo.refresh(unifiedUsername: "A")
        #expect(await repo.cached(unifiedUsername: "A").map(\.id) == ["E2"])
    }
}

extension PhyExpTests {
    @Test func overridesFromCacheArePerStudent() async throws {
        let database = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let repository = PhyExpRepository(database: database, client: FakePEC(result: .success(try fixture())))
        #expect(await PhyExpOverrides.cached(database: database, unifiedUsername: "A").isEmpty)
        _ = try await repository.refresh(unifiedUsername: "A")
        let overrides = await PhyExpOverrides.cached(database: database, unifiedUsername: "A")
        #expect(overrides.count == 2)
        #expect(overrides.allSatisfy { $0.courseNameContains == "物理实验" && ($0.teacher?.isEmpty == false) })
        #expect(await PhyExpOverrides.cached(database: database, unifiedUsername: "B").isEmpty)
    }
}

extension PhyExpTests {
    @Test func practiceDatesUseGregorianComponentsInTheDeviceTimeZone() throws {
        let zone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = zone
        var lab = try #require(try PhyExpParser.parse(try fixture()).first)
        lab.dateText = "20261008"
        let expected = try #require(gregorian.date(from: DateComponents(year: 2026, month: 10, day: 8)))
        for id in [Calendar.Identifier.buddhist, .chinese] {
            var device = Calendar(identifier: id)
            device.timeZone = zone
            #expect(lab.date(calendar: device) == expected)
            let table = Data(#"{"datas":[[{"startRow":2,"startCol":1,"content":"10月8日"}]]}"#.utf8)
            let days = try EngTrainingParser.parse(table, now: expected, calendar: device)
            #expect(days.map(\.date) == [expected])
        }
    }

    @Test func previousAccountAndLegacyJwCachesStayHiddenWhenRefreshFails() async throws {
        let database = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let source = PhyExpRepository(database: database, client: FakePEC(result: .success(try fixture())))
        let labs = try await source.refresh(unifiedUsername: "A")
        let lab = try #require(labs.first)
        try await database.writer.write { db in
            try db.execute(sql: "INSERT INTO phy_experiment (studentId, id, json) VALUES ('B', ?, ?)",
                           arguments: [lab.id, try JSONEncoder().encode(lab)])
        }
        let offline = PhyExpRepository(database: database, client: FakePEC(result: .failure(.network("offline"))))
        await #expect(throws: GxuError.network("offline")) { try await offline.refresh(unifiedUsername: "B") }
        #expect(await offline.cached(unifiedUsername: "B").isEmpty)
        #expect(await offline.cached(unifiedUsername: "A") == labs)
    }
}
