import Foundation
import GxuFoundation
import GRDB
import GxuTestSupport
import Testing
@testable import GxuStorage

struct StorageTests {
    @Test func migrationsFromAllFeaturesRun() throws {
        let a = FeatureMigrations(feature: "a") { $0.registerMigration("a.v1.create") { try $0.create(table: "a") { $0.autoIncrementedPrimaryKey("id") } } }
        let b = FeatureMigrations(feature: "b") { $0.registerMigration("b.v1.create") { try $0.create(table: "b") { $0.autoIncrementedPrimaryKey("id") } } }
        let db = try AppDatabase.inMemory(features: [a, b])
        let tables = try db.writer.read { try String.fetchAll($0, sql: "SELECT name FROM sqlite_master WHERE type='table'") }
        #expect(tables.contains("a") && tables.contains("b"))
    }

    @Test func sharedStoreRoundTrips() {
        let store = InMemorySharedStore()
        let key = SharedKey<[String]>("names")
        #expect(store.value(key) == nil)
        store.set(["a", "b"], for: key)
        #expect(store.value(key) == ["a", "b"])
        store.set(nil, for: key)
        #expect(store.value(key) == nil)
    }

    @Test func userDefaultsStoreRoundTrips() {
        let store = UserDefaultsSharedStore(suiteName: nil)
        let key = SharedKey<Int>("test.\(UUID().uuidString)")
        store.set(42, for: key)
        #expect(store.value(key) == 42)
        store.set(nil, for: key)
        #expect(store.value(key) == nil)
    }


    @Test func databaseFallsBackToApplicationSupportWithoutAppGroup() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #expect(AppDatabase.databaseDirectory(appGroupID: nil) == appSupport)
    }

    @Test func databaseCanBeOpenedAndUsedInTheFallbackDirectory() throws {
        let appSupport = AppDatabase.databaseDirectory(appGroupID: nil)
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let path = appSupport.appending(path: "fallback-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let pool = try DatabasePool(path: path)
        let database = try AppDatabase(writer: pool, features: [])
        try database.writer.write { try $0.execute(sql: "CREATE TABLE t (x INTEGER)"); try $0.execute(sql: "INSERT INTO t VALUES (1)") }
        #expect(try database.writer.read { try Int.fetchOne($0, sql: "SELECT x FROM t") } == 1)
    }

    @Test func sharedStoreSkipsAnUnavailableAppGroupButKeepsOtherSuites() {
        #expect(UserDefaultsSharedStore.resolveSuite("group.x", appGroupID: "group.x", containerExists: { _ in false }) == nil)
        #expect(UserDefaultsSharedStore.resolveSuite("group.x", appGroupID: "group.x", containerExists: { _ in true }) == "group.x")
        #expect(UserDefaultsSharedStore.resolveSuite("my.debug.suite", appGroupID: "group.x", containerExists: { _ in false }) == "my.debug.suite")
        #expect(UserDefaultsSharedStore.resolveSuite(nil, appGroupID: nil, containerExists: { _ in true }) == nil)
    }

    @Test func sharedStoreWithAnUnavailableAppGroupStillWorks() {
        let store = UserDefaultsSharedStore(suiteName: GxuConfig.appGroupID)
        let key = SharedKey<Int>("test.\(UUID().uuidString)")
        store.set(7, for: key)
        #expect(store.value(key) == 7)
        store.set(nil, for: key)
    }
}
