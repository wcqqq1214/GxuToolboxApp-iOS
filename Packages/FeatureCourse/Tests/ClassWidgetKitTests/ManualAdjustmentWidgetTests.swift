import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import ScheduleKit
import Testing
@testable import ClassWidgetKit

struct ManualAdjustmentWidgetTests {
    @Test func widgetAndDayQueryFollowLocalMoveAndRestore() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/profile/startDay", json: #"{"data":[{"year":2026,"term":1,"day":"2026-09-07","week":20}]}"#)
        backend.stub("GET /jw/schedule/personal", json: #"{"data":{"theoryList":[{"courseName":"数学","classId":"math-a","weeks":[1],"weekday":1,"sectionRange":"1-2","venueName":"旧教室"}]}}"#)
        let database = try AppDatabase.inMemory(features: [ScheduleKit.migrations])
        let repo = ScheduleRepository(backend: backend, database: database)
        let days = try await repo.refreshStartDays()
        let term = AcademicTerm(year: 2026, term: 1)
        let startDay = try #require(days.first)
        let calendar = try #require(TermCalendar(startDay))
        let cached = try await repo.refreshSchedule(studentId: "demo", term: term)
        let source = try #require(ScheduleExpander.occurrences(of: cached.schedule, in: calendar).first)
        let change = ManualCourseAdjustment(sourceID: source.id, week: 1, weekday: 2, begin: 3, end: 4, location: "新教室")
        try await repo.saveManualCourseAdjustments([change], studentId: "demo", term: term)
        let widget = await SnapshotProvider.compute(studentId: "demo", database: database, now: source.date, calendar: calendar.calendar)
        #expect(widget.today.isEmpty)
        #expect(widget.tomorrow.map(\.room) == ["新教室"])
        #expect(widget.next?.beginTime == "10:00")
        let oldDay = try await ScheduleQuery.courses(on: source.date, studentId: "demo", database: database, calendar: calendar.calendar)
        let newDay = try await ScheduleQuery.courses(on: calendar.date(week: 1, weekday: 2), studentId: "demo", database: database, calendar: calendar.calendar)
        #expect(oldDay.isEmpty)
        #expect(newDay.map(\.room) == ["新教室"])
        let direct = NextCourseCalculator.compute(schedule: cached.schedule, term: calendar, adjustments: [change], now: source.date)
        #expect(direct.next == widget.next)
        try await repo.deleteManualCourseAdjustment(id: source.id, studentId: "demo", term: term)
        let restored = await SnapshotProvider.compute(studentId: "demo", database: database, now: source.date, calendar: calendar.calendar)
        #expect(restored.today.map(\.room) == ["旧教室"])
    }
}
