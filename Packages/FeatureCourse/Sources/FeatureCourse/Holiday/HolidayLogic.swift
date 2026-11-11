import GxuFoundation
import ExamKit
import Foundation
import ScheduleKit

enum DayText {
    static func parse(_ text: String, calendar: Calendar) -> Date? {
        let calendar = calendar.gregorianEquivalent
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let comps = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: comps) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        guard back.year == parts[0], back.month == parts[1], back.day == parts[2] else { return nil }
        return date
    }

    static func monthDay(_ date: Date, calendar: Calendar) -> String {
        let calendar = calendar.gregorianEquivalent
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)月\(c.day ?? 0)日"
    }

    static func monthDayWeekday(_ date: Date, calendar: Calendar) -> String {
        let calendar = calendar.gregorianEquivalent
        let weekday = (calendar.component(.weekday, from: date) + 5) % 7
        return "\(monthDay(date, calendar: calendar))（周\(["一", "二", "三", "四", "五", "六", "日"][weekday])）"
    }
}

struct HolidayEntry: Equatable, Identifiable {
    enum Status: Equatable { case ongoing, upcoming, past }

    var holiday: HolidayRange
    var from: Date
    var to: Date
    var status: Status
    var days: Int
    var makeupDays: [Date]
    var daysUntil: Int?

    var id: String { "\(holiday.title)@\(holiday.from)" }

    var rangeText: String {
        let cal = Calendar(identifier: .gregorian)
        return from == to ? DayText.monthDay(from, calendar: cal) : "\(DayText.monthDay(from, calendar: cal))–\(DayText.monthDay(to, calendar: cal))"
    }
}

enum HolidayPresentation {
    static func build(
        _ campus: CampusCalendar, now: Date, calendar: Calendar = .current
    ) -> (current: [HolidayEntry], past: [HolidayEntry]) {
        let today = calendar.startOfDay(for: now)
        let shifts = campus.timeShift.compactMap { rule -> (work: Date, rest: Date)? in
            guard let w = DayText.parse(rule.workDate, calendar: calendar), let r = DayText.parse(rule.restDate, calendar: calendar) else { return nil }
            return (w, r)
        }
        var entries: [HolidayEntry] = []
        for h in campus.holidays {
            guard let from = DayText.parse(h.from, calendar: calendar), let to = DayText.parse(h.to, calendar: calendar), from <= to else { continue }
            let days = (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
            let status: HolidayEntry.Status = to < today ? .past : (from <= today ? .ongoing : .upcoming)
            let makeup = shifts.filter { $0.rest >= from && $0.rest <= to }.map(\.work).sorted()
            let until = status == .upcoming ? calendar.dateComponents([.day], from: today, to: from).day : nil
            entries.append(HolidayEntry(holiday: h, from: from, to: to, status: status, days: days, makeupDays: makeup, daysUntil: until))
        }
        let current = entries.filter { $0.status != .past }.sorted { $0.from < $1.from }
        let past = entries.filter { $0.status == .past }.sorted { $0.to > $1.to }
        return (current, past)
    }
}

struct TimeShiftEntry: Equatable, Identifiable {
    var workDay: Date
    var restDay: Date
    var isPast: Bool
    var id: String { "\(workDay.timeIntervalSince1970)-\(restDay.timeIntervalSince1970)" }
}

enum TimeShiftPresentation {
    static func build(_ campus: CampusCalendar, now: Date, calendar: Calendar = .current) -> (current: [TimeShiftEntry], past: [TimeShiftEntry]) {
        let today = calendar.startOfDay(for: now)
        let all = campus.timeShift.compactMap { rule -> TimeShiftEntry? in
            guard let w = DayText.parse(rule.workDate, calendar: calendar), let r = DayText.parse(rule.restDate, calendar: calendar) else { return nil }
            return TimeShiftEntry(workDay: w, restDay: r, isPast: w < today)
        }
        return (all.filter { !$0.isPast }.sorted { $0.workDay < $1.workDay }, all.filter(\.isPast).sorted { $0.workDay > $1.workDay })
    }
}
