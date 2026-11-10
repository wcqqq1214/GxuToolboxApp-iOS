import Foundation
import GxuFoundation

/// 要画在周网格上的一场考试。考试数据在 ExamKit 里，ScheduleKit 不依赖它，所以由 Shell 转换后注入。
public struct GridExam: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var location: String
    /// 座位文案，没有则为空串
    public var seat: String
    public var start: Date
    public var end: Date
    /// 考试来源学期（缓存时记录的学年 / 学期）。相关考试按它过滤；缺失时不匹配，不靠考试日期猜
    public var term: AcademicTerm?

    public init(id: String, title: String, location: String = "", seat: String = "", start: Date, end: Date, term: AcademicTerm? = nil) {
        self.id = id
        self.title = title
        self.location = location
        self.seat = seat
        self.start = start
        self.end = end
        self.term = term
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

/// 课程详情里的“相关考试”：按课程名匹配，按开考时间排序，并给出 RN `CourseExamCard` 的状态角标
public enum RelatedExams {
    /// 同名课程在往届（如重修前）也有考试，只取课表正在查看的学期；考试没有来源学期信息时不匹配
    public static func matching(courseName: String, in exams: [GridExam], term: AcademicTerm?) -> [GridExam] {
        let name = courseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let term else { return [] }
        return exams.filter { $0.term == term && $0.title.trimmingCharacters(in: .whitespaces) == name }.sorted { $0.start < $1.start }
    }

    /// 已结束 / 今天考试 / N 天后
    public static func badge(for exam: GridExam, now: Date, calendar: Calendar = .current) -> String {
        if exam.end <= now { return "已结束" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: exam.start)).day ?? 0
        return days <= 0 ? "今天考试" : "\(days) 天后"
    }
}
