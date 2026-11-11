import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import ScheduleKit

struct TodayAndConflictTests {
    let mathMon = course("高等数学", weekday: 3, 1, 2, weeks: Array(1...18), teacher: "甲")
    let english = course("大学英语", weekday: 3, 3, 4, weeks: Array(1...18), teacher: "乙")
    let physics = course("大学物理", weekday: 3, 3, 4, weeks: Array(1...18), teacher: "丙")

    private func occurrences(_ courses: [TheoryCourse]) -> [CourseOccurrence] {
        ScheduleExpander.occurrences(of: Schedule(theoryList: courses), in: term)
    }

    @Test func todayPlanFindsCurrentAndNext() {
        let all = occurrences([mathMon, english])
        let before = TodayPlan.make(occurrences: all, dayBlocks: [], term: term, now: at("2026-09-16 07:00"))
        #expect(before.phase == .inTerm && before.week == 2 && before.weekday == 3)
        #expect(before.current == nil)
        #expect(before.next?.course.courseName == "高等数学")
        #expect(!before.nextIsTomorrow)

        let during = TodayPlan.make(occurrences: all, dayBlocks: [], term: term, now: at("2026-09-16 08:45"))
        #expect(during.current?.course.courseName == "高等数学")
        #expect(during.next?.course.courseName == "大学英语")
        #expect(during.status(of: during.courses[0], now: at("2026-09-16 08:45")) == .ongoing)
    }

    @Test func nextFallsToTomorrow() {
        let thursday = course("体育", weekday: 4, 1, 2, weeks: Array(1...18))
        let plan = TodayPlan.make(occurrences: occurrences([mathMon, thursday]), dayBlocks: [], term: term, now: at("2026-09-16 20:00"))
        #expect(plan.current == nil)
        #expect(plan.next?.course.courseName == "体育")
        #expect(plan.nextIsTomorrow)
        #expect(plan.tomorrow.count == 1)
    }

    @Test func termPhases() {
        let all = occurrences([mathMon])
        #expect(TodayPlan.make(occurrences: all, dayBlocks: [], term: term, now: at("2026-09-01")).phase == .beforeTerm(daysUntilStart: 6))
        #expect(TodayPlan.make(occurrences: all, dayBlocks: [], term: term, now: at("2027-03-01")).phase == .afterTerm)
    }

    @Test func dayNotes() {
        let campus = CampusCalendar(
            timeShift: [ShiftRule(workDate: "2026-09-20", restDate: "2026-09-16")],
            holidays: [HolidayRange(title: "中秋节", from: "2026-09-25", to: "2026-09-27")]
        )
        let overlaid = CalendarOverlay.apply(to: occurrences([mathMon]), calendar: campus, term: term)
        let holiday = TodayPlan.make(occurrences: overlaid.occurrences, dayBlocks: overlaid.dayBlocks, term: term, now: at("2026-09-25 09:00"))
        #expect(holiday.note == .holiday("中秋节"))
        #expect(holiday.courses.isEmpty)
        let rest = TodayPlan.make(occurrences: overlaid.occurrences, dayBlocks: overlaid.dayBlocks, term: term, now: at("2026-09-16 09:00"))
        #expect(rest.note == .rest)
        let makeup = TodayPlan.make(occurrences: overlaid.occurrences, dayBlocks: overlaid.dayBlocks, term: term, now: at("2026-09-20 09:00"))
        #expect(makeup.note == .makeup(from: at("2026-09-16")))
        #expect(makeup.courses.count == 1)
    }


    @Test func conflictKeyIsOrderIndependent() {
        let all = occurrences([english, physics]).filter { $0.week == 2 }
        let group = ScheduleExpander.conflictGroups(all)[0]
        #expect(group.isConflict)
        #expect(ConflictGroup(items: group.items.reversed()).key == group.key)
    }

    @Test func selectionDefaultsToFirstAndHonorsChoice() {
        let group = ScheduleExpander.conflictGroups(occurrences([english, physics]).filter { $0.week == 2 })[0]
        #expect(group.selected(choices: [:]) == group.items[0])
        let other = group.items[1]
        #expect(group.selected(choices: [group.key: ScheduleExpander.selectionKey(other.course)]) == other)
        #expect(group.selected(choices: [group.key: "不存在_x"]) == group.items[0])
    }

    @Test func resolverKeepsOnlySelectedPerGroup() {
        let all = occurrences([mathMon, english, physics]).filter { $0.week == 2 }
        let group = ScheduleExpander.conflictGroups(all.filter { $0.begin == 3 })[0]
        let chosen = group.items[1]
        let resolved = ConflictResolver.resolve(all, choices: [group.key: ScheduleExpander.selectionKey(chosen.course)])
        #expect(resolved.count == 2)
        #expect(resolved.contains { $0.course == chosen.course })
    }

    @Test func todayPlanUsesChoice() {
        let all = occurrences([english, physics])
        let group = ScheduleExpander.conflictGroups(all.filter { $0.week == 2 })[0]
        let chosen = group.items[1]
        let plan = TodayPlan.make(
            occurrences: all, dayBlocks: [], term: term,
            choices: [group.key: ScheduleExpander.selectionKey(chosen.course)], now: at("2026-09-16 07:00")
        )
        #expect(plan.courses.map(\.course) == [chosen.course])
    }

    @Test func choicesPersistPerStudentAndTerm() async throws {
        let db = try AppDatabase.inMemory(features: [ScheduleKit.migrations])
        let repository = ScheduleRepository(backend: MockBackendAPI(), database: db)
        let term1 = AcademicTerm(year: 2026, term: 1)
        try await repository.setConflictChoice("大学物理_丙", groupKey: "k", studentId: "A", term: term1)
        try await repository.setConflictChoice("大学英语_乙", groupKey: "k", studentId: "A", term: term1)
        #expect(await repository.conflictChoices(studentId: "A", term: term1) == ["k": "大学英语_乙"])
        #expect(await repository.conflictChoices(studentId: "B", term: term1).isEmpty)
        #expect(await repository.conflictChoices(studentId: "A", term: AcademicTerm(year: 2026, term: 2)).isEmpty)
    }

    @Test func cachedSnapshotNeedsCache() async throws {
        let db = try AppDatabase.inMemory(features: [ScheduleKit.migrations])
        let repository = ScheduleRepository(backend: MockBackendAPI(), database: db)
        #expect(await repository.cachedSnapshot(studentId: "A", now: at("2026-09-16 09:00"), calendar: shanghai) == nil)
    }
}
