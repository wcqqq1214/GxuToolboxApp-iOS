import Foundation
import GxuAuth
import GxuStorage
import Testing
@testable import GxuToolApp

@MainActor
struct AppStartupTests {
    @Test func failedFeatureMigrationPreservesCustomCoursesChoicesAndTemplates() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "gxu_tool.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let features = FeatureRegistry.migrations
        do {
            let database = try AppDatabase.open(features: features, at: url)
            try database.writer.write { db in
                try db.execute(sql: "INSERT INTO schedule_custom_activity VALUES (?, ?, ?, ?, ?)",
                               arguments: ["demo", 2026, 1, "activity", Data("{}".utf8)])
                try db.execute(sql: "INSERT INTO schedule_conflict_choice VALUES (?, ?, ?, ?, ?)",
                               arguments: ["demo", 2026, 1, "group", "choice"])
                try db.execute(sql: "INSERT INTO evaluation_template (studentId, name, answersJSON, comment, updatedAt) VALUES (?, ?, ?, ?, ?)",
                               arguments: ["demo", "My template", "[]", "Saved comment", "2026-01-01"])
            }
        }
        let broken = FeatureMigrations(feature: "broken") { migrator in
            migrator.registerMigration("broken") { db in
                try db.execute(sql: "DELETE FROM schedule_custom_activity")
                try db.execute(sql: "DELETE FROM schedule_conflict_choice")
                try db.execute(sql: "DELETE FROM evaluation_template")
                throw CocoaError(.fileWriteUnknown)
            }
        }
        #expect(throws: (any Error).self) { try AppDatabase.open(features: features + [broken], at: url) }
        let reopened = try AppDatabase.open(features: features, at: url)
        let activities = try reopened.writer.read { try String.fetchAll($0, sql: "SELECT id FROM schedule_custom_activity") }
        let choices = try reopened.writer.read { try String.fetchAll($0, sql: "SELECT choice FROM schedule_conflict_choice") }
        let comments = try reopened.writer.read { try String.fetchAll($0, sql: "SELECT comment FROM evaluation_template") }
        #expect(activities == ["activity"])
        #expect(choices == ["choice"])
        #expect(comments == ["Saved comment"])
    }

    @Test func failedStartupCanRetryWithoutPublishingServices() async {
        var attempts = 0
        let services = AppServices.preview()
        let model = AppStartupModel {
            attempts += 1
            if attempts == 1 { throw CocoaError(.fileReadCorruptFile) }
            return services
        }
        await model.start()
        guard case .failed(let code) = model.state else {
            Issue.record("打开失败时应显示恢复页")
            return
        }
        #expect(code.contains("NSCocoaErrorDomain"))
        await model.start()
        guard case .ready = model.state else {
            Issue.record("重试成功时应进入应用")
            return
        }
        await model.start()
        #expect(attempts == 2)
    }

    @Test func concurrentStartsDoNotOpenTheDatabaseTwice() async {
        let (events, continuation) = AsyncStream<Void>.makeStream()
        var attempts = 0
        let model = AppStartupModel {
            attempts += 1
            for await _ in events { break }
            return AppServices.preview()
        }
        let first = Task { await model.start() }
        while attempts == 0 { await Task.yield() }
        await model.start()
        #expect(attempts == 1)
        continuation.finish()
        await first.value
        guard case .ready = model.state else {
            Issue.record("打开成功后应有可用服务")
            return
        }
    }
}
