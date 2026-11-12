import Foundation
import GxuFoundation
import GxuStorage
import Testing
@testable import CampusKit
@testable import FeatureCampus

private struct FakePEC: PECClient { let data: Data; func ruleManage() async throws -> Data { data } }

struct PhyExpRefreshTests {
    @Test func nullExperimentFieldsUseFallbacksAndNullDatesAreSkipped() throws {
        let raw = #"{"d":"{\"data\":[{\"id\":\"1\",\"skrq\":\"20261008\",\"xmmc\":null,\"kcmc\":\"大学物理实验\",\"fjbh\":null,\"sysmc\":\"实验室A\"}]}"}"#
        let e = try PhyExpParser.parse(Data(raw.utf8))[0]
        #expect(e.title == "大学物理实验")
        #expect(e.place == "实验室A")
        let nullDate = #"{"d":"{\"data\":[{\"id\":\"1\",\"skrq\":null,\"xmmc\":\"x\"}]}"}"#
        #expect(try PhyExpParser.parse(Data(nullDate.utf8)).isEmpty)
    }

    @Test func unexpectedPayloadKeepsCachedEntries() async throws {
        let db = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let goodPec = #"{"d":"{\"data\":[{\"id\":\"1\",\"skrq\":\"20261008\",\"xmmc\":\"x\"}]}"}"#
        _ = try await PhyExpRepository(database: db, client: FakePEC(data: Data(goodPec.utf8))).refresh(unifiedUsername: "A")
        let renamed = #"{"d":"{\"data\":[{\"id\":\"1\",\"rq\":\"20261008\",\"xmmc\":\"x\"}]}"}"#
        _ = try? await PhyExpRepository(database: db, client: FakePEC(data: Data(renamed.utf8))).refresh(unifiedUsername: "A")
        let phy = await PhyExpRepository(database: db, client: FakePEC(data: Data())).cached(unifiedUsername: "A").count
        #expect(phy == 1)
    }

    @Test func corruptCachedRowIsSkippedAndLogged() async throws {
        let db = try AppDatabase.inMemory(features: [CampusFeature.migrations])
        let good = #"{"d":"{\"data\":[{\"id\":\"1\",\"skrq\":\"20261008\",\"xmmc\":\"x\"}]}"}"#
        _ = try await PhyExpRepository(database: db, client: FakePEC(data: Data(good.utf8))).refresh(unifiedUsername: "A")
        try await db.writer.write { db in
            try db.execute(sql: "INSERT INTO phy_experiment (studentId, id, json) VALUES ('unified:A', 'bad', ?)", arguments: [Data("{}".utf8)])
        }
        let cached = await PhyExpRepository(database: db, client: FakePEC(data: Data())).cached(unifiedUsername: "A")
        #expect(cached.map(\.id) == ["1"])
        #expect(ErrorLog.shared.contents().contains("[cache] 解码物理实验缓存失败"))
    }
}
