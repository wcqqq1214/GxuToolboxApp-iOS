import Foundation

/// 要画在周网格上的一场考试。考试数据在 ExamKit 里，ScheduleKit 不依赖它，所以由 Shell 转换后注入。
public struct GridExam: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var location: String
    /// 座位文案，没有则为空串
    public var seat: String
    public var start: Date
    public var end: Date

    public init(id: String, title: String, location: String = "", seat: String = "", start: Date, end: Date) {
        self.id = id
        self.title = title
        self.location = location
        self.seat = seat
        self.start = start
        self.end = end
    }
}

/// 周网格里的考试块
public struct ExamBlock: Sendable, Hashable, Identifiable {
    public var exam: GridExam
    public var week: Int
    /// 1 = 周一
    public var weekday: Int
    /// 占用的节次（含），1-based
    public var begin: Int
    public var end: Int
    public var id: String { exam.id }
}

public enum ExamPlacement {
    /// 考试时间 → 占用的节次。规则同 RN `normalizeExam`：
    /// - 开始节 = 第一个“下课时间晚于考试开始”的节次；
    /// - 结束节 = 最后一个“上课时间早于考试结束”的节次（严格早于）。
    /// 找不到时返回 nil（例如整场考试在 22:05 之后）。
    public static func periods(start: Date, end: Date, calendar: Calendar = .current) -> (begin: Int, end: Int)? {
        func minutes(_ date: Date) -> Int {
            let c = calendar.dateComponents([.hour, .minute], from: date)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        let startMinutes = minutes(start), endMinutes = minutes(end)
        guard
            let begin = ClassPeriods.all.first(where: { $0.end.hour * 60 + $0.end.minute > startMinutes }),
            let last = ClassPeriods.all.last(where: { $0.start.hour * 60 + $0.start.minute < endMinutes })
        else { return nil }
        return (begin.number, max(last.number, begin.number))
    }

    /// 考试 → 网格块。不在本学期的周内、或换算不出节次的考试被丢弃。考试固定在日历日期上，不随调课移动。
    public static func blocks(for exams: [GridExam], term: TermCalendar) -> [ExamBlock] {
        exams.compactMap { exam in
            let week = term.week(containing: exam.start)
            guard (1...term.weekCount).contains(week), let range = periods(start: exam.start, end: exam.end, calendar: term.calendar) else { return nil }
            return ExamBlock(exam: exam, week: week, weekday: term.weekday(of: exam.start), begin: range.begin, end: range.end)
        }
        .sorted { ($0.week, $0.weekday, $0.begin, $0.id) < ($1.week, $1.weekday, $1.begin, $1.id) }
    }
}
