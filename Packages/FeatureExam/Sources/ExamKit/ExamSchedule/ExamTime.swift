import Foundation

import GxuFoundation

public enum ExamStatus: String, Sendable, Equatable {
    case upcoming, past, tbd
}

public struct ParsedExamTime: Equatable, Sendable {
    public var date: Date?
    public let endsAt: Date?
    public var status: ExamStatus

    public init(date: Date?, endsAt: Date? = nil, status: ExamStatus) {
        self.date = date
        self.endsAt = endsAt
        self.status = status
    }
}

public enum ExamTimeParser {
    public static func parse(_ time: String, now: Date = .now, calendar: Calendar = .current) -> ParsedExamTime {
        let calendar = calendar.gregorianEquivalent
        let pattern = /(\d{4})-(\d{2})-(\d{2})\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)/
        guard let m = time.firstMatch(of: pattern),
              let y = Int(m.1), let mo = Int(m.2), let d = Int(m.3),
              let sh = Int(m.4), let sm = Int(m.5), let eh = Int(m.6), let em = Int(m.7),
              let start = makeDate(y, mo, d, sh, sm, calendar),
              let end = makeDate(y, mo, d, eh, em, calendar)
        else { return ParsedExamTime(date: nil, status: .tbd) }
        return ParsedExamTime(date: start, endsAt: end, status: end < now ? .past : .upcoming)
    }

    private static func makeDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ calendar: Calendar) -> Date? {
        let comps = DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)
        guard let date = calendar.date(from: comps) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard back.year == y, back.month == mo, back.day == d, back.hour == h, back.minute == mi else { return nil }
        return date
    }
}

public struct ExamItem: Hashable, Sendable, Identifiable {
    public var exam: Exam
    public var date: Date?
    public let endsAt: Date?
    public var status: ExamStatus
    public var id: String { exam.id }

    public init(_ exam: Exam, now: Date = .now, calendar: Calendar = .current) {
        let parsed = ExamTimeParser.parse(exam.time, now: now, calendar: calendar)
        self.exam = exam
        self.date = parsed.date
        self.endsAt = parsed.endsAt
        self.status = parsed.status
    }

    public func timeLine(now: Date = .now, calendar: Calendar = .current) -> String {
        let calendar = calendar.gregorianEquivalent
        guard let date else {
            let time = exam.time.trimmingCharacters(in: .whitespacesAndNewlines)
            return ["", "待定", "时间未定"].contains(time) ? "时间待定" : time
        }
        let c = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        let clock = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        return isUrgent(now: now, calendar: calendar) ? clock : "\(c.month ?? 0)月\(c.day ?? 0)日 \(clock)"
    }

    public func isUrgent(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let text = countdownText(now: now, calendar: calendar) else { return false }
        return text == "今日开考" || text == "明日开考"
    }

    public func countdownText(now: Date = .now, calendar: Calendar = .current) -> String? {
        let calendar = calendar.gregorianEquivalent
        guard status == .upcoming, let date else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? -1
        switch days {
        case ..<0: return nil
        case 0: return "今日开考"
        case 1: return "明日开考"
        default: return "\(days)天后"
        }
    }
}

public struct ExamSections: Equatable, Sendable {
    public var upcoming: [ExamItem]
    public var past: [ExamItem]

    public init(upcoming: [ExamItem] = [], past: [ExamItem] = []) {
        self.upcoming = upcoming
        self.past = past
    }
}

public enum ExamSorting {
    public static func sorted(_ items: [ExamItem]) -> [ExamItem] {
        func rank(_ s: ExamStatus) -> Int {
            switch s {
            case .upcoming: 0
            case .tbd: 1
            case .past: 2
            }
        }
        return items.enumerated().sorted { a, b in
            let ra = rank(a.element.status), rb = rank(b.element.status)
            if ra != rb { return ra < rb }
            let ta = a.element.date?.timeIntervalSince1970 ?? 0
            let tb = b.element.date?.timeIntervalSince1970 ?? 0
            if ta != tb { return ra == 0 ? ta < tb : ta > tb }
            return a.offset < b.offset
        }.map(\.element)
    }

    public static func sections(_ items: [ExamItem]) -> ExamSections {
        let all = sorted(items)
        return ExamSections(upcoming: all.filter { $0.status != .past }, past: all.filter { $0.status == .past })
    }
}

public enum NextExam {
    public static func upcoming(in items: [ExamItem]) -> [ExamItem] {
        items.filter { $0.status == .upcoming && $0.date != nil }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    public static func pick(from items: [ExamItem]) -> ExamItem? { upcoming(in: items).first }
}

public enum ExamSeat {
    public static func text(_ seat: String) -> String {
        let seat = seat.trimmingCharacters(in: .whitespacesAndNewlines)
        if seat.isEmpty { return "" }
        return seat.allSatisfy(\.isNumber) ? "\(seat) 号" : "座位 \(seat)"
    }
}
