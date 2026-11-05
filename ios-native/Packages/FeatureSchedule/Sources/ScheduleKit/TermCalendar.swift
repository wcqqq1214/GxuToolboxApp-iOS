import Foundation

/// 一个学期的周历。所有日期都是日历所在时区的“某天 00:00”，按天计算，避免 UTC 偏移差一天。
public struct TermCalendar: Sendable, Equatable {
    public let startDate: Date
    public let weekCount: Int
    public let calendar: Calendar

    public init(startDate: Date, weekCount: Int, calendar: Calendar = .current) {
        self.calendar = calendar
        self.startDate = calendar.startOfDay(for: startDate)
        self.weekCount = max(weekCount, 1)
    }

    public init?(_ termStartDay: TermStartDay, calendar: Calendar = .current) {
        guard let date = Self.parseDay(termStartDay.day, calendar: calendar), termStartDay.week > 0 else { return nil }
        self.init(startDate: date, weekCount: termStartDay.week, calendar: calendar)
    }

    /// `YYYY-MM-DD` 直接取日期；带时区的 ISO 8601（如 `2026-09-06T16:00:00.000Z`）先转成瞬间，再换算成日历时区的日期。
    static func parseDay(_ text: String, calendar: Calendar) -> Date? {
        let text = text.trimmingCharacters(in: .whitespaces)
        if text.count > 10, text.contains("T") {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            if let instant = formatter.date(from: text) ?? plain.date(from: text) {
                return calendar.startOfDay(for: instant)
            }
        }
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// 第 `week` 周的星期 `weekday`（1 = 周一）那天
    public func date(week: Int, weekday: Int) -> Date {
        calendar.date(byAdding: .day, value: (week - 1) * 7 + weekday - 1, to: startDate) ?? startDate
    }

    /// 某天属于第几周。学期开始前 ≤ 0，结束后 > weekCount。
    public func week(containing date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: startDate, to: calendar.startOfDay(for: date)).day ?? 0
        return Int((Double(days) / 7).rounded(.down)) + 1
    }

    /// 1 = 周一 … 7 = 周日
    public func weekday(of date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    public func isStarted(at date: Date) -> Bool { week(containing: date) >= 1 }
    public func isEnded(at date: Date) -> Bool { week(containing: date) > weekCount }

    /// 夹到 `1...weekCount` 的“本周”
    public func clampedWeek(at date: Date) -> Int { min(max(week(containing: date), 1), weekCount) }

    /// 学期最后一天之后的那天（即下个学期的“更新日”提示用）
    public var endDate: Date { date(week: weekCount + 1, weekday: 1) }
}

public enum TermResolver {
    /// 按开始日升序，第一个“今天还没过结束日”的是当前学期；都过了取最后一个。不信任后端的 `is_current`。
    public static func current(in terms: [TermStartDay], now: Date, calendar: Calendar = .current) -> TermStartDay? {
        let sorted = terms.compactMap { term in TermCalendar(term, calendar: calendar).map { (term, $0) } }
            .sorted { $0.1.startDate < $1.1.startDate }
        let today = calendar.startOfDay(for: now)
        return (sorted.first { today < $0.1.endDate } ?? sorted.last)?.0
    }
}
