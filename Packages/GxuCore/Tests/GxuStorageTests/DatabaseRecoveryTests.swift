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

    @Test func failedMigrationExportsTheOriginalDamagedWALAcrossRetries() throws {
        let source = try temporaryDatabase()
        let target = try temporaryDatabase()
        defer {
            try? FileManager.default.removeItem(at: source.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: target.deletingLastPathComponent())
        }
        let targetWAL = URL(fileURLWithPath: target.path + "-wal")
        let original: Data
        var damagedWAL: Data
        do {
            let queue = try DatabaseQueue(path: source.path)
            try queue.writeWithoutTransaction { db in
                try db.execute(sql: "CREATE TABLE custom_activity (name TEXT NOT NULL)")
                try db.execute(sql: "CREATE TABLE collision (id INTEGER)")
                try db.execute(sql: "PRAGMA journal_mode = WAL")
                try db.execute(sql: "INSERT INTO custom_activity VALUES ('Recoverable course')")
            }
            original = try Data(contentsOf: source)
            damagedWAL = try Data(contentsOf: URL(fileURLWithPath: source.path + "-wal"))
        }
        try #require(damagedWAL.count > 48)
        try #require(damagedWAL.range(of: Data("Recoverable course".utf8)) != nil)
        damagedWAL[48] ^= 1
        try original.write(to: target)
        try damagedWAL.write(to: targetWAL)

        let migration = FeatureMigrations(feature: "test") { migrator in
            migrator.registerMigration("collision") { db in
                try db.execute(sql: "CREATE TABLE collision (id INTEGER)")
            }
        }
        for _ in 0..<2 {
            do {
                _ = try AppDatabase.open(features: [migration], at: target)
                Issue.record("Expected the migration to fail")
            } catch let error as DatabaseError {
                #expect(error.message?.contains("table collision already exists") == true)
            }
            let backup = try PropertyListDecoder().decode(DatabaseBackup.self, from: DatabaseBackup.capture(at: target))
            #expect(backup.files[target.lastPathComponent] == original)
            #expect(backup.files[targetWAL.lastPathComponent] == damagedWAL)
        }

        _ = try AppDatabase.open(features: [], at: target)
        let entries = try FileManager.default.contentsOfDirectory(at: target.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        let archive = try #require(entries.first { $0.lastPathComponent.hasPrefix(target.lastPathComponent + ".recovery-") })
        #expect(try Data(contentsOf: archive.appending(path: target.lastPathComponent)) == original)
        #expect(try Data(contentsOf: archive.appending(path: targetWAL.lastPathComponent)) == damagedWAL)
    }

    @Test func backupCanBeCapturedFromAReadOnlyDirectory() throws {
        let url = try temporaryDatabase()
        let directory = url.deletingLastPathComponent()
        let fm = FileManager.default
        defer {
            try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? fm.removeItem(at: directory)
        }
        let original = Data("readable original database".utf8)
        try original.write(to: url)
        try fm.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        let encoded = try DatabaseBackup.capture(at: url)
        let backup = try PropertyListDecoder().decode(DatabaseBackup.self, from: encoded)
        #expect(backup.files[url.lastPathComponent] == original)
        #expect(try fm.contentsOfDirectory(atPath: directory.path) == [url.lastPathComponent])
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
