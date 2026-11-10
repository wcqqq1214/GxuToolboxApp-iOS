import Foundation

/// RN `NextEventBanner` 把假期图层的每一天也当作一个“事件”：开始时间取第 1 节上课时间（08:00），
/// 在所有事件里取开始时间最早的，同一时刻假期排在课程前面（假期图层在最底层，排序是稳定的）。
public struct NextHoliday: Sendable, Equatable {
    public var title: String
    public var date: Date
    public var startsAt: Date

    /// 还没开始的第一个假期日（只算假期，不含调休休息日）
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

    /// RN `daysFromNow`：今天 / 明天 / N天后
    public func dayText(now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if days <= 0 { return "今天" }
        return days == 1 ? "明天" : "\(days) 天后"
    }
}
