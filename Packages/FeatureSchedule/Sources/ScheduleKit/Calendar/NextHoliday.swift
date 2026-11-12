import Foundation
import GxuFoundation

public struct NextHoliday: Sendable, Equatable {
    public enum Status: Sendable, Equatable { case upcoming, ongoing }

    public let title: String
    public let date: Date
    public let startsAt: Date
    public let status: Status

    public var isOngoing: Bool { status == .ongoing }

    public var displayTitle: String {
        isOngoing && (title == "寒假" || title == "暑假") ? "\(title)中" : title
    }

    public static func next(holidays: [HolidayRange], calendar: Calendar, now: Date) -> NextHoliday? {
        let calendar = calendar.gregorianEquivalent
        let today = calendar.startOfDay(for: now)
        let candidates = holidays.compactMap { holiday -> NextHoliday? in
            guard let start = TermCalendar.parseDay(holiday.from, calendar: calendar),
                  let end = TermCalendar.parseDay(holiday.to, calendar: calendar),
                  start <= end, today <= end else { return nil }
            return NextHoliday(title: holiday.title, date: start, startsAt: start,
                               status: start <= today ? .ongoing : .upcoming)
        }
        return candidates.min {
            if $0.isOngoing != $1.isOngoing { return $0.isOngoing }
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.title < $1.title
        }
    }

    public func dayText(now: Date, calendar: Calendar) -> String {
        if isOngoing { return "放假中" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if days <= 0 { return "今天" }
        return days == 1 ? "明天" : "\(days) 天后"
    }
}
