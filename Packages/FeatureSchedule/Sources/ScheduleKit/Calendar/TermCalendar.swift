import Foundation
import GxuFoundation

public struct TermCalendar: Sendable, Equatable {
    static let maximumWeeks = 53

    public let startDate: Date
    public let weekCount: Int
    public let calendar: Calendar

    public init(startDate: Date, weekCount: Int, calendar: Calendar = .current) {
        let calendar = calendar.gregorianEquivalent
        self.calendar = calendar
        self.startDate = calendar.startOfDay(for: startDate)
        self.weekCount = min(max(weekCount, 1), Self.maximumWeeks)
    }

    public init?(_ termStartDay: TermStartDay, calendar: Calendar = .current) {
        guard (1...Self.maximumWeeks).contains(termStartDay.week),
              let date = Self.parseDay(termStartDay.day, calendar: calendar) else { return nil }
        self.init(startDate: date, weekCount: termStartDay.week, calendar: calendar)
    }

    static func parseDay(_ text: String, calendar: Calendar) -> Date? {
        let calendar = calendar.gregorianEquivalent
        let text = text.trimmingCharacters(in: .whitespaces)
        if text.count > 10, text.contains("T"), !isUTCMidnight(text) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            if let instant = formatter.date(from: text) ?? plain.date(from: text) {
                return calendar.startOfDay(for: instant)
            }
        }
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        return back.year == parts[0] && back.month == parts[1] && back.day == parts[2] ? date : nil
    }

    private static func isUTCMidnight(_ text: String) -> Bool {
        text.range(of: #"^\d{4}-\d{2}-\d{2}T00:00(:00(\.0+)?)?(Z|\+00:?00)$"#, options: .regularExpression) != nil
    }

    public func date(week: Int, weekday: Int) -> Date {
        calendar.date(byAdding: .day, value: (week - 1) * 7 + weekday - 1, to: startDate) ?? startDate
    }

    public func week(containing date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: startDate, to: calendar.startOfDay(for: date)).day ?? 0
        return Int((Double(days) / 7).rounded(.down)) + 1
    }

    public func weekday(of date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    public func isStarted(at date: Date) -> Bool { week(containing: date) >= 1 }
    public func isEnded(at date: Date) -> Bool { week(containing: date) > weekCount }

    public func clampedWeek(at date: Date) -> Int { min(max(week(containing: date), 1), weekCount) }

    public var endDate: Date { date(week: weekCount + 1, weekday: 1) }
}

public enum TermResolver {
    public static func current(in terms: [TermStartDay], now: Date, calendar: Calendar = .current) -> TermStartDay? {
        let sorted = terms.compactMap { term in TermCalendar(term, calendar: calendar).map { (term, $0) } }
            .sorted { $0.1.startDate < $1.1.startDate }
        let today = calendar.gregorianEquivalent.startOfDay(for: now)
        return (sorted.first { today < $0.1.endDate } ?? sorted.last)?.0
    }
}
