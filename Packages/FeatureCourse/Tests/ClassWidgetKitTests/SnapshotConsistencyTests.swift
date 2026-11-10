import Foundation
import GxuFoundation
import GxuStorage
import Testing
import ScheduleKit
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

/// 小组件快照和 App Intent 必须和 App 里的"今天"一致：用户选的冲突课程、自定义日程都要算进去
@Suite struct SnapshotConsistencyTests {
    /// 数据库里存的课表和算冲突组键的课表必须是同一份（课程 id / 键里含教室、教师）
    private static let schedule = Schedule(theoryList: [
        TheoryCourse(venueName: "A1", sectionRange: "1-2", begin: 1, end: 2, courseName: "AAA", weeks: [1], teacher: "t1", weekday: 1),
        TheoryCourse(venueName: "B1", sectionRange: "1-2", begin: 1, end: 2, courseName: "BBB", weeks: [1], teacher: "t2", weekday: 1),
    ])

    private func database() async throws -> (AppDatabase, ScheduleRepository) {
        let db = try AppDatabase.inMemory(features: [ScheduleKit.migrations])
        let repo = ScheduleRepository(backend: UnavailableBackend(), database: db)
        // 2026-11-02（周一）是 2026 秋季第 1 周
        try await db.writer.write { d in
            try d.execute(sql: "INSERT INTO term_start_day (year, term, day, week) VALUES (2026, 1, '2026-11-02', 20)")
            let json = try JSONEncoder().encode(Self.schedule)
            try d.execute(
                sql: "INSERT INTO schedule_snapshot (studentId, year, term, json, updatedAt) VALUES ('s1', 2026, 1, ?, 0)",
                arguments: [json]
            )
        }
        return (db, repo)
    }

    @Test func widgetSnapshotAndIntentHonourConflictChoiceAndCustomActivity() async throws {
        let (db, repo) = try await database()
        let term = AcademicTerm(year: 2026, term: 1)
        let day = at("2026-11-02 07:00")

        // 没做选择时：冲突组默认第一门，不会同时出现两门
        let defaultToday = await SnapshotProvider.compute(studentId: "s1", database: db, now: day, calendar: cal).today.map(\.name)
        #expect(defaultToday.count == 1)

        // 用户选 BBB，并加了一个第 3–4 节的自定义日程
        let termCalendar = try #require(TermCalendar(TermStartDay(year: 2026, term: 1, day: "2026-11-02", week: 20), calendar: cal))
        let schedule = Self.schedule
        let group = try #require(ScheduleExpander.conflictGroups(ScheduleExpander.occurrences(of: schedule, in: termCalendar)).first)
        try await repo.setConflictChoice(ScheduleExpander.selectionKey(schedule.theoryList[1]), groupKey: group.key, studentId: "s1", term: term)
        try await repo.saveCustomActivity(CustomActivity(name: "CUSTOM", weekday: 1, begin: 3, end: 4, weekFrom: 1, weekTo: 1), studentId: "s1", term: term)

        let snapshot = await SnapshotProvider.compute(studentId: "s1", database: db, now: day, calendar: cal)
        #expect(snapshot.today.map(\.name) == ["BBB", "CUSTOM"])
        let intent = try await ScheduleQuery.courses(on: day, studentId: "s1", database: db, calendar: cal)
        #expect(intent.map(\.name) == ["BBB", "CUSTOM"])
        #expect(ScheduleQuery.describe(dayName: "今天", courses: intent).hasPrefix("今天有 2 节课"))
        #expect(await SnapshotProvider.hadClasses(on: day, studentId: "s1", database: db, calendar: cal))
        // 别的账号不受影响
        let other = await SnapshotProvider.compute(studentId: "s2", database: db, now: day, calendar: cal)
        #expect(other.state == .missingSchedule)
    }
}
