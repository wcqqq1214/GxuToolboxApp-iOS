import FeatureCampus
import Foundation
import GxuStorage
import ScheduleKit
import Testing
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

/// 小组件 / App Intent 里的"物理实验"课要显示 PEC 的教师和地点（和课表页一致）；别的课、别的日期、别的账号不受影响
@Suite struct PhyExpOverrideTests {
    // 周一第 1–2 节物理实验（第 1 周、第 2 周各一次），同一时段没有别的课
    private static let schedule = Schedule(theoryList: [
        TheoryCourse(venueName: "原教室", sectionRange: "1-2", begin: 1, end: 2, courseName: "大学物理实验", weeks: [1, 2], teacher: "原教师", weekday: 1),
        TheoryCourse(venueName: "A1", sectionRange: "3-4", begin: 3, end: 4, courseName: "高等数学", weeks: [1, 2], teacher: "数学老师", weekday: 1),
    ])

    private func database() async throws -> AppDatabase {
        let db = try AppDatabase.inMemory(features: [ScheduleKit.migrations, CampusFeature.migrations])
        // 2026-11-02（周一）是 2026 秋季第 1 周；PEC 只给第 1 周（11-02）这一天换教师和地点
        let lab = Data(#"{"id":"e1","week":"1","className":"","dateText":"20261102","timeText":"08:00","courseName":"大学物理实验","experimentName":"光的干涉","teacher":"PEC教师","location":"实验楼301","labName":""}"#.utf8)
        try await db.writer.write { d in
            try d.execute(sql: "INSERT INTO term_start_day (year, term, day, week) VALUES (2026, 1, '2026-11-02', 20)")
            try d.execute(sql: "INSERT INTO schedule_snapshot (studentId, year, term, json, updatedAt) VALUES ('s1', 2026, 1, ?, 0)",
                          arguments: [try JSONEncoder().encode(Self.schedule)])
            try d.execute(sql: "INSERT INTO phy_experiment (studentId, id, json) VALUES ('s1', 'e1', ?)", arguments: [lab])
        }
        return db
    }

    @Test func widgetSnapshotAndIntentShowPecTeacherAndPlace() async throws {
        let db = try await database()
        let monday = at("2026-11-02 07:00")
        let snapshot = await SnapshotProvider.compute(studentId: "s1", database: db, now: monday, calendar: cal)
        let lab = try #require(snapshot.today.first { $0.name == "大学物理实验" })
        #expect(lab.room == "实验楼301" && lab.teacher == "PEC教师")
        #expect(snapshot.today.first { $0.name == "高等数学" }?.room == "A1")   // 别的课不变
        let intent = try await ScheduleQuery.courses(on: monday, studentId: "s1", database: db, calendar: cal)
        #expect(intent.first { $0.name == "大学物理实验" }?.room == "实验楼301")
        // 没有 PEC 记录的日期（第 2 周周一）保持课表原样
        let next = try await ScheduleQuery.courses(on: at("2026-11-09 07:00"), studentId: "s1", database: db, calendar: cal)
        #expect(next.first { $0.name == "大学物理实验" }?.room == "原教室" && next.first?.teacher == "原教师")
        // 别的账号读不到 s1 的实验课记录
        let other = await PhyExpOverrides.cached(database: db, studentId: "s2", calendar: cal)
        #expect(other.isEmpty)
    }
}
