import Foundation

public enum ScheduleDataState: String, Codable, Sendable {
    case ready, missingSchedule, missingStartDay, error
}

/// 小组件 / Live Activity / 底部附件栏用的紧凑课程
public struct WidgetCourse: Codable, Sendable, Hashable, Identifiable {
    public var name: String
    public var beginTime: String
    public var endTime: String
    /// 节次区间，如 "1-2"
    public var index: String
    public var teacher: String
    public var room: String
    /// `yyyy-MM-dd`
    public var date: String
    public var startsAt: Date
    public var endsAt: Date

    public var id: String { "\(name)|\(date)|\(index)|\(room)" }

    public init(_ occurrence: CourseOccurrence, calendar: Calendar) {
        let course = occurrence.course
        name = course.courseName
        beginTime = ClassPeriods.period(course.begin)?.startText ?? ""
        endTime = ClassPeriods.period(course.end)?.endText ?? ""
        index = course.sectionRange
        teacher = course.teacher
        room = course.venueName
        date = Self.dateKey(occurrence.date, calendar: calendar)
        startsAt = occurrence.startsAt
        endsAt = occurrence.endsAt
    }

    static func dateKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

public struct NextCourses: Codable, Sendable, Equatable {
    public var state: ScheduleDataState
    /// 今天还没结束的课（正在上的也在内）
    public var today: [WidgetCourse]
    public var tomorrow: [WidgetCourse]
    /// 下一节还没开始的课（正在上的不算）
    public var next: WidgetCourse?
    /// 数据下次需要重新计算的时间
    public var nextRefreshAt: Date?
    public var refreshedAt: Date

    public static func empty(_ state: ScheduleDataState, now: Date) -> NextCourses {
        NextCourses(state: state, today: [], tomorrow: [], next: nil, nextRefreshAt: nil, refreshedAt: now)
    }
}

public enum NextCourseCalculator {
    public static func compute(occurrences: [CourseOccurrence], now: Date, calendar: Calendar = .current) -> NextCourses {
        let sorted = occurrences.sorted { $0.startsAt < $1.startsAt }
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        let today = sorted.filter { $0.date == todayStart && $0.endsAt > now }
        let tomorrow = sorted.filter { $0.date == tomorrowStart }
        let next = sorted.first { $0.startsAt > now }

        let nextEnd = sorted.first { $0.endsAt > now }?.endsAt.addingTimeInterval(1)
        let midnight = tomorrowStart.addingTimeInterval(1)
        let refresh = min(nextEnd ?? .distantFuture, midnight)

        return NextCourses(
            state: .ready,
            today: today.map { WidgetCourse($0, calendar: calendar) },
            tomorrow: tomorrow.map { WidgetCourse($0, calendar: calendar) },
            next: next.map { WidgetCourse($0, calendar: calendar) },
            nextRefreshAt: refresh,
            refreshedAt: now
        )
    }

    public static func compute(schedule: Schedule?, term: TermCalendar?, campus: CampusCalendar = .empty, now: Date) -> NextCourses {
        guard let schedule else { return .empty(.missingSchedule, now: now) }
        guard let term else { return .empty(.missingStartDay, now: now) }
        let occurrences = CalendarOverlay.apply(to: ScheduleExpander.occurrences(of: schedule, in: term), calendar: campus, term: term).occurrences
        return compute(occurrences: occurrences, now: now, calendar: term.calendar)
    }
}
