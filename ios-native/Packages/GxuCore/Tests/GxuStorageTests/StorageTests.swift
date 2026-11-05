import Foundation
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
}
