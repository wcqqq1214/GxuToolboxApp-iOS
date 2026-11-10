import Foundation
import GxuFoundation

/// 一份可直接使用的课表：课表 + 学期周历 + 节假日 / 补班叠加 + 冲突选择。首页、小组件、App Intent 用。
public struct ScheduleSnapshot: Sendable {
    public var term: AcademicTerm
    public var termCalendar: TermCalendar
    public var schedule: Schedule
    public var campus: CampusCalendar
    public var choices: [String: String]
    public var activities: [CustomActivity]
    /// 已叠加节假日 / 补班，冲突组里的课都在
    public var occurrences: [CourseOccurrence]
    public var dayBlocks: [DayBlock]
    public var updatedAt: Date

    /// 自定义日程的颜色（按名字），传给 `CourseColorAssigner.assign(custom:)`
    public var customColors: [String: UInt32] { Dictionary(activities.map { ($0.name, $0.colorHex) }, uniquingKeysWith: { first, _ in first }) }

    public func todayPlan(now: Date = .now) -> TodayPlan {
        TodayPlan.make(occurrences: occurrences, dayBlocks: dayBlocks, term: termCalendar, choices: choices, now: now)
    }
}

extension ScheduleRepository {
    /// 只读本地缓存（不联网）的当前学期课表。没有缓存的课表 / 学期开始日时返回 nil。
    /// - Parameter overrides: 按日期覆盖教师 / 地点（实验课，来自别的模块），先于节假日叠加应用，和课表页一致
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
