import Foundation

public enum ExamStatus: String, Sendable, Equatable {
    case upcoming, past, tbd
}

public struct ParsedExamTime: Equatable, Sendable {
    /// 开始时间，用于排序和展示
    public var date: Date?
    public var status: ExamStatus

    public init(date: Date?, status: ExamStatus) {
        self.date = date
        self.status = status
    }
}

/// 移植自 RN `parseExamTime`。
public enum ExamTimeParser {
    /// 解析 `2023-01-01(09:00-11:00)`。结束时间严格早于 `now` 为 past，否则 upcoming；
    /// 不匹配或日期时间越界（RN 的 dayjs 会滚动进位，这里有意判为 tbd）为 tbd。
    public static func parse(_ time: String, now: Date = .now, calendar: Calendar = .current) -> ParsedExamTime {
        let pattern = /(\d{4})-(\d{2})-(\d{2})\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)/
        guard let m = time.firstMatch(of: pattern),
              let y = Int(m.1), let mo = Int(m.2), let d = Int(m.3),
              let sh = Int(m.4), let sm = Int(m.5), let eh = Int(m.6), let em = Int(m.7),
              let start = makeDate(y, mo, d, sh, sm, calendar),
              let end = makeDate(y, mo, d, eh, em, calendar)
        else { return ParsedExamTime(date: nil, status: .tbd) }
        return ParsedExamTime(date: start, status: end < now ? .past : .upcoming)
    }

    private static func makeDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ calendar: Calendar) -> Date? {
        let comps = DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)
        guard let date = calendar.date(from: comps) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard back.year == y, back.month == mo, back.day == d, back.hour == h, back.minute == mi else { return nil }
        return date
    }
}

/// 带运行时状态的考试（状态不入库，每次读取时按 `time` 重新计算）
public struct ExamItem: Hashable, Sendable, Identifiable {
    public var exam: Exam
    public var date: Date?
    public var status: ExamStatus
    public var id: String { exam.id }

    public init(_ exam: Exam, now: Date = .now, calendar: Calendar = .current) {
        let parsed = ExamTimeParser.parse(exam.time, now: now, calendar: calendar)
        self.exam = exam
        self.date = parsed.date
        self.status = parsed.status
    }

    /// 今日或明日开考（界面只对这两种用红色强调）
    public func isUrgent(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let text = countdownText(now: now, calendar: calendar) else { return false }
        return text == "今日开考" || text == "明日开考"
    }

    /// 距开考的日历天数文案：今日开考 / 明日开考 / N天后；已过或没有日期时为 nil
    public func countdownText(now: Date = .now, calendar: Calendar = .current) -> String? {
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
    /// upcoming + tbd
    public var upcoming: [ExamItem]
    public var past: [ExamItem]

    public init(upcoming: [ExamItem] = [], past: [ExamItem] = []) {
        self.upcoming = upcoming
        self.past = past
    }
}

public enum ExamSorting {
    /// upcoming 在前且按开始时间升序；tbd、past 按开始时间降序（无日期按 0）。同序保持原顺序。
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

/// "下一场考试"的纯逻辑：不依赖界面和存储，B 的首页、课表叠加、小组件、App Intent 共用
public enum NextExam {
    /// 状态为 upcoming 且有开考时间的考试，按开考时间升序
    public static func upcoming(in items: [ExamItem]) -> [ExamItem] {
        items.filter { $0.status == .upcoming && $0.date != nil }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    public static func pick(from items: [ExamItem]) -> ExamItem? { upcoming(in: items).first }
}
