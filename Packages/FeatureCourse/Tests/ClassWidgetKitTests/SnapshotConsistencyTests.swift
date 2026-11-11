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

@Suite struct SnapshotConsistencyTests {
    private static let schedule = Schedule(theoryList: [
        TheoryCourse(venueName: "A1", sectionRange: "1-2", begin: 1, end: 2, courseName: "AAA", weeks: [1], teacher: "t1", weekday: 1),
        TheoryCourse(venueName: "B1", sectionRange: "1-2", begin: 1, end: 2, courseName: "BBB", weeks: [1], teacher: "t2", weekday: 1),
    ])

    private func database() async throws -> (AppDatabase, ScheduleRepository) {
        let db = try AppDatabase.inMemory(features: [ScheduleKit.migrations])
        let repo = ScheduleRepository(backend: UnavailableBackend(), database: db)
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

        let defaultToday = await SnapshotProvider.compute(studentId: "s1", database: db, now: day, calendar: cal).today.map(\.name)
        #expect(defaultToday.count == 1)

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
        #expect(await SnapshotProvider.hasScheduledClasses(on: day, studentId: "s1", database: db, calendar: cal))
        let other = await SnapshotProvider.compute(studentId: "s2", database: db, now: day, calendar: cal)
        #expect(other.state == .missingSchedule)
    }

    @Test func widgetTimelineMatchesAppAcrossMidnightBeforeMakeupClass() async throws {
        let (db, repo) = try await database()
        let campus = CampusCalendarRepository(database: db, fetch: { _ in
            Data(#"{"timeShift":[["2026-11-03","2026-11-02"]],"holidays":[]}"#.utf8)
        })
        _ = try await campus.refresh()
        let night = at("2026-11-02 22:00")
        let midnight = at("2026-11-03 00:00")
        let snapshot = await SnapshotProvider.compute(studentId: "s1", database: db, now: night, calendar: cal)
        let app = try #require(await repo.cachedSnapshot(studentId: "s1", now: night, calendar: cal))
        let nightPlan = app.todayPlan(now: night)
        let morningPlan = app.todayPlan(now: midnight)
        let timeline = ScheduleTimeline.entries(snapshot: snapshot, now: night, calendar: cal)
        let overnight = try #require(timeline.entries.first { $0.date == midnight })

        #expect(nightPlan.nextIsTomorrow)
        #expect(nightPlan.next?.isMakeup == true)
        #expect(snapshot.next?.startsAt == nightPlan.next?.startsAt)
        #expect(snapshot.next?.name == nightPlan.next?.course.courseName)
        #expect(overnight.focus?.startsAt == morningPlan.next?.startsAt)
        #expect(overnight.focus?.name == morningPlan.next?.course.courseName)
    }

    @Test func widgetKnowsTodayHadClassesAfterTheLastOneEnds() async throws {
        let (db, repo) = try await database()
        let afterClass = at("2026-11-02 22:00")
        let app = try #require(await repo.cachedSnapshot(studentId: "s1", now: afterClass, calendar: cal))
        let plan = app.todayPlan(now: afterClass)
        let monday = await SnapshotProvider.dailySnapshot(studentId: "s1", database: db, unifiedUsername: nil, now: afterClass, calendar: cal)
        #expect(monday.courses.state == .ready)
        #expect(monday.courses.today.isEmpty)
        #expect(monday.hasClassesToday)
        #expect(plan.courses.allSatisfy { plan.status(of: $0, now: afterClass) == .finished })
        #expect(plan.current == nil && plan.next == nil)
        #expect(monday.courses.next == nil)

        let tuesday = await SnapshotProvider.dailySnapshot(studentId: "s1", database: db, unifiedUsername: nil, now: at("2026-11-03 22:00"), calendar: cal)
        #expect(tuesday.courses.state == .ready)
        #expect(!tuesday.hasClassesToday)
    }
}
