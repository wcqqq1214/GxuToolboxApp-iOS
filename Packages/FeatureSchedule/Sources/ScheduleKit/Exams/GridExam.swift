import Foundation
import GxuFoundation

public struct GridExam: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var location: String
    public var seat: String
    public var start: Date
    public var end: Date
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

public struct ExamBlock: Sendable, Hashable, Identifiable {
    public var exam: GridExam
    public var week: Int
    public var weekday: Int
    public var begin: Int
    public var end: Int
    public var id: String { exam.id }
}

public enum ExamPlacement {
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

    public static func blocks(for exams: [GridExam], term: TermCalendar) -> [ExamBlock] {
        exams.compactMap { exam in
            let week = term.week(containing: exam.start)
            guard (1...term.weekCount).contains(week), let range = periods(start: exam.start, end: exam.end, calendar: term.calendar) else { return nil }
            return ExamBlock(exam: exam, week: week, weekday: term.weekday(of: exam.start), begin: range.begin, end: range.end)
        }
        .sorted { ($0.week, $0.weekday, $0.begin, $0.id) < ($1.week, $1.weekday, $1.begin, $1.id) }
    }
}

public enum RelatedExams {
    public static func matching(courseName: String, in exams: [GridExam], term: AcademicTerm?) -> [GridExam] {
        let name = courseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let term else { return [] }
        return exams.filter { $0.term == term && $0.title.trimmingCharacters(in: .whitespaces) == name }.sorted { $0.start < $1.start }
    }

    public static func badge(for exam: GridExam, now: Date, calendar: Calendar = .current) -> String {
        if exam.end <= now { return "已结束" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: exam.start)).day ?? 0
        return days <= 0 ? "今天考试" : "\(days) 天后"
    }
}
