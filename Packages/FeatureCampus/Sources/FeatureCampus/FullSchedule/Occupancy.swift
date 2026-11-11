import Foundation
import ScheduleKit

public struct ClassMoment: Sendable, Hashable {
    public var week: Int
    public var weekday: Int
    public var period: Int

    public init(week: Int, weekday: Int, period: Int) {
        self.week = week
        self.weekday = weekday
        self.period = period
    }

    public static func now(term: TermCalendar, now: Date = .now) -> ClassMoment {
        let minutes = Double(ClassPeriods.position(at: now, calendar: term.calendar))
        let period = min(max(Int(minutes.rounded(.down)) + 1, 1), ClassPeriods.count)
        return ClassMoment(week: term.clampedWeek(at: now), weekday: term.weekday(of: now), period: period)
    }
}

public enum Occupancy {
    public static func course(in schedule: Schedule, at moment: ClassMoment) -> TheoryCourse? {
        schedule.theoryList.first { course in
            course.isValid && course.weekday == moment.weekday && course.weeks.contains(moment.week)
                && (course.begin...course.end).contains(moment.period)
        }
    }
}
