import Foundation
import GxuFoundation

public struct ScheduleSnapshot: Sendable {
    public var term: AcademicTerm
    public var termCalendar: TermCalendar
    public var schedule: Schedule
    public var campus: CampusCalendar
    public var choices: [String: String]
    public var activities: [CustomActivity]
    public var occurrences: [CourseOccurrence]
    public var dayBlocks: [DayBlock]
    public var updatedAt: Date

    public var customColors: [String: UInt32] { Dictionary(activities.map { ($0.name, $0.colorHex) }, uniquingKeysWith: { first, _ in first }) }

    public func todayPlan(now: Date = .now) -> TodayPlan {
        TodayPlan.make(occurrences: occurrences, dayBlocks: dayBlocks, term: termCalendar, choices: choices, now: now)
    }
}

extension ScheduleRepository {
    public func cachedSnapshot(studentId: String, now: Date = .now, calendar: Calendar = .current, overrides: [OccurrenceOverride] = []) async -> ScheduleSnapshot? {
        let startDays = (try? await cachedStartDays()) ?? []
        guard
            let current = TermResolver.current(in: startDays, now: now, calendar: calendar),
            let termCalendar = TermCalendar(current, calendar: calendar),
            let cached = try? await cachedSchedule(studentId: studentId, term: current.academicTerm)
        else { return nil }
        let campus = await CampusCalendarRepository(database: database).current()
        let choices = await conflictChoices(studentId: studentId, term: current.academicTerm)
        let activities = await customActivities(studentId: studentId, term: current.academicTerm)
        var schedule = cached.schedule
        schedule.theoryList += activities.filter(\.isValid).map(\.course)
        let base = OccurrenceOverrides.apply(overrides, to: ScheduleExpander.occurrences(of: schedule, in: termCalendar))
        let overlaid = CalendarOverlay.apply(to: base, calendar: campus, term: termCalendar)
        return ScheduleSnapshot(
            term: current.academicTerm, termCalendar: termCalendar, schedule: schedule, campus: campus, choices: choices, activities: activities,
            occurrences: overlaid.occurrences, dayBlocks: overlaid.dayBlocks, updatedAt: cached.updatedAt
        )
    }
}
