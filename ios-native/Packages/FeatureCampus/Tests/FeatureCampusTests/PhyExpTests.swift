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
        #expect(await ok.cached(studentId: "A").isEmpty)
        let fresh = try await ok.refresh(studentId: "A")
        #expect(fresh.count == 2)
        #expect(await ok.cached(studentId: "A").map(\.id) == ["E1", "E2"])
        #expect(await ok.cached(studentId: "B").isEmpty)           // 账号隔离

        let failing = PhyExpRepository(database: database, client: FakePEC(result: .failure(.notLoggedIn(.unified))))
        await #expect(throws: GxuError.self) { try await failing.refresh(studentId: "A") }
        #expect(await failing.cached(studentId: "A").count == 2)   // 失败保留旧缓存
    }

    @Test func refreshReplacesCancelledEntries() async throws {
        let database = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        _ = try await PhyExpRepository(database: database, client: FakePEC(result: .success(try fixture()))).refresh(studentId: "A")
        let smaller = #"{"d":"{\"data\":[{\"ID\":\"E2\",\"SKRQ\":\"20251015\",\"XMMC\":\"光栅衍射\"}]}"}"#
        let repo = PhyExpRepository(database: database, client: FakePEC(result: .success(Data(smaller.utf8))))
        _ = try await repo.refresh(studentId: "A")
        #expect(await repo.cached(studentId: "A").map(\.id) == ["E2"])
    }
}
