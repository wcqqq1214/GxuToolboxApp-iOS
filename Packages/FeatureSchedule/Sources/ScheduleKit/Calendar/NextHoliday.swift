import Foundation

public struct NextHoliday: Sendable, Equatable {
    public var title: String
    public var date: Date
    public var startsAt: Date

    public static func next(dayBlocks: [DayBlock], term: TermCalendar, now: Date) -> NextHoliday? {
        guard let first = ClassPeriods.period(1) else { return nil }
        return dayBlocks
            .filter { if case .holiday = $0.kind { true } else { false } }
            .compactMap { block -> NextHoliday? in
                guard let start = term.calendar.date(bySettingHour: first.start.hour, minute: first.start.minute, second: 0, of: block.date)
                else { return nil }
                return NextHoliday(title: block.title, date: block.date, startsAt: start)
            }
            .filter { $0.startsAt > now }
            .min { $0.startsAt < $1.startsAt }
    }

    public func dayText(now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if days <= 0 { return "今天" }
        return days == 1 ? "明天" : "\(days) 天后"
    }
}
