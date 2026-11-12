import FeatureCampus
import Foundation
import GxuStorage
import ScheduleKit
import Testing
@testable import CampusKit
@testable import ClassWidgetKit

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return c
}()

private func at(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}

@Suite struct PhyExpOverrideTests {
    private static let schedule = Schedule(theoryList: [
        TheoryCourse(venueName: "原教室", sectionRange: "1-2", begin: 1, end: 2, courseName: "大学物理实验", weeks: [1, 2], teacher: "原教师", weekday: 1),
        TheoryCourse(venueName: "A1", sectionRange: "3-4", begin: 3, end: 4, courseName: "高等数学", weeks: [1, 2], teacher: "数学老师", weekday: 1),
    ])

    private func database() async throws -> AppDatabase {
        let db = try AppDatabase.inMemory(features: [ScheduleKit.migrations, CampusFeature.migrations])
        let lab = Data(#"{"id":"e1","week":"1","className":"","dateText":"20261102","timeText":"08:00","courseName":"大学物理实验","experimentName":"光的干涉","teacher":"PEC教师","location":"实验楼301","labName":""}"#.utf8)
        try await db.writer.write { d in
            try d.execute(sql: "INSERT INTO term_start_day (year, term, day, week) VALUES (2026, 1, '2026-11-02', 20)")
            try d.execute(sql: "INSERT INTO schedule_snapshot (studentId, year, term, json, updatedAt) VALUES ('s1', 2026, 1, ?, 0)",
                          arguments: [try JSONEncoder().encode(Self.schedule)])
            try d.execute(sql: "INSERT INTO phy_experiment (studentId, id, json) VALUES ('unified:cas-A', 'e1', ?)", arguments: [lab])
        }
        return db
    }

    @Test func widgetSnapshotAndIntentShowPecTeacherAndPlace() async throws {
        let db = try await database()
        let monday = at("2026-11-02 07:00")
        let snapshot = await SnapshotProvider.compute(studentId: "s1", database: db, unifiedUsername: "cas-A", now: monday, calendar: cal)
        let lab = try #require(snapshot.today.first { $0.name == "大学物理实验" })
        #expect(lab.room == "实验楼301" && lab.teacher == "PEC教师")
        #expect(snapshot.today.first { $0.name == "高等数学" }?.room == "A1")
        let intent = try await ScheduleQuery.courses(on: monday, studentId: "s1", database: db, unifiedUsername: "cas-A", calendar: cal)
        #expect(intent.first { $0.name == "大学物理实验" }?.room == "实验楼301")
        let next = try await ScheduleQuery.courses(on: at("2026-11-09 07:00"), studentId: "s1", database: db, unifiedUsername: "cas-A", calendar: cal)
        #expect(next.first { $0.name == "大学物理实验" }?.room == "原教室" && next.first?.teacher == "原教师")
        let other = await PhyExpOverrides.cached(database: db, unifiedUsername: "cas-B", calendar: cal)
        #expect(other.isEmpty)
        let switched = await SnapshotProvider.compute(studentId: "s1", database: db, unifiedUsername: "cas-B", now: monday, calendar: cal)
        #expect(switched.today.first { $0.name == "大学物理实验" }?.room == "原教室")
    }
}
