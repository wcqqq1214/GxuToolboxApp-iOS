import Foundation
import ScheduleKit

/// “全校课表”的查询时刻：第几周、星期几（1 = 周一）、第几节
public struct ClassMoment: Sendable, Hashable {
    public var week: Int
    public var weekday: Int
    public var period: Int

    public init(week: Int, weekday: Int, period: Int) {
        self.week = week
        self.weekday = weekday
        self.period = period
    }

    /// 默认时刻：今天，正在上的那节；课间 / 午休取下一节；当天最后一节之后取最后一节。学期外夹到 1...weekCount。
    public static func now(term: TermCalendar, now: Date = .now) -> ClassMoment {
        let minutes = Double(ClassPeriods.position(at: now, calendar: term.calendar))
        // `position` 以“节”为单位：整数部分是已经走过的节数
        let period = min(max(Int(minutes.rounded(.down)) + 1, 1), ClassPeriods.count)
        return ClassMoment(week: term.clampedWeek(at: now), weekday: term.weekday(of: now), period: period)
    }
}

public enum Occupancy {
    /// 这个班在 `moment` 这一节上的课（理论课）。没课返回 nil。
    public static func course(in schedule: Schedule, at moment: ClassMoment) -> TheoryCourse? {
        schedule.theoryList.first { course in
            course.isValid && course.weekday == moment.weekday && course.weeks.contains(moment.week)
                && (course.begin...course.end).contains(moment.period)
        }
    }
}
