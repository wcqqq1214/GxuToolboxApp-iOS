import Foundation
import Testing
@testable import GxuStorage

struct DatabaseRecoveryTests {
    private func temporaryDatabase() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "gxu_tool.sqlite")
    }

    @Test func corruptDatabaseSurvivesRepeatedOpenAttemptsAndBackup() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let original = Data("damaged database with irreplaceable content".utf8)
        try original.write(to: url)
        for _ in 0..<2 {
            #expect(throws: (any Error).self) { try AppDatabase.open(features: [], at: url) }
            #expect(try Data(contentsOf: url) == original)
        }
        let backup = try PropertyListDecoder().decode(DatabaseBackup.self, from: DatabaseBackup.capture(at: url))
        #expect(backup.formatVersion == 1)
        #expect(backup.files[url.lastPathComponent] == original)
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func failedMigrationRollsBackAndRetryPreservesUserData() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let initial = FeatureMigrations(feature: "test") { migrator in
            migrator.registerMigration("initial") { db in
                try db.execute(sql: "CREATE TABLE custom_activity (name TEXT NOT NULL)")
                try db.execute(sql: "INSERT INTO custom_activity VALUES ('My course')")
            }
        }
        do { _ = try AppDatabase.open(features: [initial], at: url) }
        let broken = FeatureMigrations(feature: "test-broken") { migrator in
            migrator.registerMigration("next") { db in
                try db.execute(sql: "DELETE FROM custom_activity")
                throw CocoaError(.fileWriteUnknown)
            }
        }
        #expect(throws: (any Error).self) { try AppDatabase.open(features: [initial, broken], at: url) }
        let fixed = FeatureMigrations(feature: "test-fixed") { migrator in
            migrator.registerMigration("next") { db in
                try db.execute(sql: "CREATE TABLE cache (value TEXT)")
            }
        }
        let reopened = try AppDatabase.open(features: [initial, fixed], at: url)
        #expect(try reopened.writer.read { try String.fetchAll($0, sql: "SELECT name FROM custom_activity") } == ["My course"])
    }

    @Test func backupIncludesSidecarsWithoutChangingOrIncludingOtherFiles() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var expected: [String: Data] = [:]
        for suffix in ["", "-wal", "-shm", "-journal"] {
            let data = Data("raw file \(suffix)".utf8)
            try data.write(to: URL(fileURLWithPath: url.path + suffix))
            expected[url.lastPathComponent + suffix] = data
        }
        try Data("unrelated".utf8).write(to: url.deletingLastPathComponent().appending(path: "other.sqlite"))
        let backup = try PropertyListDecoder().decode(DatabaseBackup.self, from: DatabaseBackup.capture(at: url))
        #expect(backup.files == expected)
        for (name, data) in expected {
            #expect(try Data(contentsOf: url.deletingLastPathComponent().appending(path: name)) == data)
        }
    }

    @Test func missingDatabaseDoesNotProduceAnEmptyBackupOrCreateAFile() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(throws: (any Error).self) { try DatabaseBackup.capture(at: url) }
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func backupOfIdleWALDatabaseCanBeOpenedFromAnIndependentCopy() throws {
        let url = try temporaryDatabase()
        let restoredURL = try temporaryDatabase()
        defer {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: restoredURL.deletingLastPathComponent())
        }
        let database = try AppDatabase.open(features: [], at: url)
        try database.writer.write { db in
            try db.execute(sql: "CREATE TABLE custom_activity (name TEXT)")
            try db.execute(sql: "INSERT INTO custom_activity VALUES ('Saved in WAL')")
        }
        let backup = try PropertyListDecoder().decode(DatabaseBackup.self, from: DatabaseBackup.capture(at: url))
        #expect(backup.files["gxu_tool.sqlite-wal"] != nil)
        for (name, data) in backup.files {
            try data.write(to: restoredURL.deletingLastPathComponent().appending(path: name))
        }
        let restored = try AppDatabase.open(features: [], at: restoredURL)
        #expect(try restored.writer.read { try String.fetchAll($0, sql: "SELECT name FROM custom_activity") } == ["Saved in WAL"])
    }
}
