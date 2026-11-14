import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import ScheduleKit
import Testing

struct ManualAdjustmentTests {
    private var calendar: TermCalendar { TermCalendar(TermStartDay(year: 2026, term: 1, day: "2026-09-07", week: 20))! }
    private var schedule: Schedule {
        Schedule(theoryList: [TheoryCourse(venueName: "旧教室", courseName: "数学", weeks: [1, 2, 3], weekday: 1, classId: "math-a")])
    }

    @Test func oneLessonMovesAcrossWeeksAndOtherLessonsStayUnchanged() throws {
        let original = ScheduleExpander.occurrences(of: schedule, in: calendar)
        let first = try #require(original.first)
        let adjustment = ManualCourseAdjustment(sourceID: first.id, week: 4, weekday: 3, begin: 3, end: 4, location: " 新教室 ")
        let result = ManualCourseAdjustment.apply([adjustment], to: original, term: calendar)
        let moved = try #require(result.first { $0.manualAdjustmentID != nil })
        #expect(result.count == 3)
        #expect(moved.week == 4 && moved.weekday == 3 && moved.begin == 3 && moved.end == 4)
        #expect(moved.course.locationText == "新教室")
        #expect(moved.course.weeks == [4])
        #expect(moved.startsAt == calendar.calendar.date(bySettingHour: 10, minute: 0, second: 0, of: calendar.date(week: 4, weekday: 3)))
        #expect(result.filter { $0.manualAdjustmentID == nil } == Array(original.dropFirst()))
        #expect(!result.contains { $0.date == first.date })
        #expect(Set(result.map(\.id)).count == 3)
    }

    @Test func recordsPersistByAccountAndTermAndRestoreIndependently() async throws {
        let database = try AppDatabase.inMemory(features: [ScheduleKit.migrations])
        let backend = MockBackendAPI()
        let repo = ScheduleRepository(backend: backend, database: database)
        let term = AcademicTerm(year: 2026, term: 1)
        let originals = ScheduleExpander.occurrences(of: schedule, in: calendar)
        let changes = originals.prefix(2).map { ManualCourseAdjustment(sourceID: $0.id, week: $0.week, weekday: 2, begin: 5, end: 6, location: "实验室") }
        try await repo.saveManualCourseAdjustments(changes, studentId: "demo-a", term: term)
        try await repo.saveManualCourseAdjustments(changes, studentId: "demo-a", term: term)
        #expect(await repo.manualCourseAdjustments(studentId: "demo-a", term: term).count == 2)
        #expect(await repo.manualCourseAdjustments(studentId: "demo-b", term: term).isEmpty)
        #expect(await repo.manualCourseAdjustments(studentId: "demo-a", term: AcademicTerm(year: 2025, term: 1)).isEmpty)
        let reopened = ScheduleRepository(backend: backend, database: database)
        try await reopened.deleteManualCourseAdjustment(id: changes[0].id, studentId: "demo-a", term: term)
        let remaining = await reopened.manualCourseAdjustments(studentId: "demo-a", term: term)
        let restored = ManualCourseAdjustment.apply(remaining, to: originals, term: calendar)
        #expect(remaining == [changes[1]])
        #expect(restored.contains(originals[0]))
        #expect(restored.contains(originals[2]))
        #expect(backend.calls.isEmpty)
    }

    @Test func invalidBatchDoesNotPartiallyPersist() async throws {
        let repo = ScheduleRepository(backend: MockBackendAPI(), database: try .inMemory(features: [ScheduleKit.migrations]))
        let term = AcademicTerm(year: 2026, term: 1)
        let valid = ManualCourseAdjustment(sourceID: "valid", week: 1, weekday: 2, begin: 1, end: 2, location: "")
        let invalid = ManualCourseAdjustment(sourceID: "invalid", week: 0, weekday: 2, begin: 1, end: 2, location: "")
        await #expect(throws: GxuError.self) { try await repo.saveManualCourseAdjustments([valid, invalid], studentId: "demo", term: term) }
        #expect(await repo.manualCourseAdjustments(studentId: "demo", term: term).isEmpty)
    }

    @Test func missingSourcesAndCustomCoursesAreNotOverridden() throws {
        let custom = CustomActivity(name: "实验", weeks: [1]).course
        let original = ScheduleExpander.occurrences(of: Schedule(theoryList: [custom]), in: calendar)
        let first = try #require(original.first)
        let changes = [ManualCourseAdjustment(sourceID: first.id, week: 2, weekday: 3, begin: 3, end: 4, location: "错误地点"),
                       ManualCourseAdjustment(sourceID: "missing", week: 2, weekday: 3, begin: 3, end: 4, location: "错误地点")]
        #expect(ManualCourseAdjustment.apply(changes, to: original, term: calendar) == original)
    }

    @Test func legacyOccurrencesDecodeWithoutManualMarker() throws {
        let original = try #require(ScheduleExpander.occurrences(of: schedule, in: calendar).first)
        let data = try JSONEncoder().encode(original)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "manualAdjustmentID")
        let decoded = try JSONDecoder().decode(CourseOccurrence.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded == original)
        #expect(decoded.manualAdjustmentID == nil)
    }
}
