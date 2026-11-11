import Foundation

public struct CourseOccurrence: Sendable, Hashable, Identifiable, Codable {
    public let course: TheoryCourse
    public let week: Int
    public let date: Date
    public let startsAt: Date
    public let endsAt: Date
    public let weekday: Int
    public let shiftedFrom: Date?

    public var id: String {
        shiftedFrom == nil ? "\(course.id)#\(week)" : "\(course.id)#\(week)@\(weekday)"
    }
    public var isMakeup: Bool { shiftedFrom != nil }
    public var begin: Int { course.begin }
    public var end: Int { course.end }
}

public struct ConflictGroup: Sendable, Hashable, Identifiable {
    public let items: [CourseOccurrence]
    public var begin: Int { items.map(\.begin).min() ?? 1 }
    public var end: Int { items.map(\.end).max() ?? 1 }
    public var id: String { items.map(\.id).joined(separator: "&") }
    public var isConflict: Bool { items.count > 1 }
}

extension CourseOccurrence {
    public init(course: TheoryCourse, week: Int, date: Date, startsAt: Date, endsAt: Date, weekday: Int? = nil, shiftedFrom: Date? = nil) {
        self.course = course
        self.week = week
        self.date = date
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.weekday = weekday ?? course.weekday
        self.shiftedFrom = shiftedFrom
    }
}

public enum ScheduleExpander {
    public static func occurrences(of schedule: Schedule, in term: TermCalendar) -> [CourseOccurrence] {
        let calendar = term.calendar
        var result: [CourseOccurrence] = []
        for course in schedule.theoryList where course.isValid {
            guard let first = ClassPeriods.period(course.begin), let last = ClassPeriods.period(course.end) else { continue }
            for week in Set(course.weeks) where (1...TermCalendar.maximumWeeks).contains(week) {
                let day = term.date(week: week, weekday: course.weekday)
                guard
                    let start = calendar.date(bySettingHour: first.start.hour, minute: first.start.minute, second: 0, of: day),
                    let end = calendar.date(bySettingHour: last.end.hour, minute: last.end.minute, second: 0, of: day)
                else { continue }
                result.append(CourseOccurrence(course: course, week: week, date: day, startsAt: start, endsAt: end))
            }
        }
        return result.sorted { ($0.startsAt, $0.id) < ($1.startsAt, $1.id) }
    }

    public static func conflictGroups(_ items: [CourseOccurrence]) -> [ConflictGroup] {
        var groups: [[CourseOccurrence]] = []
        var currentEnd = 0
        for item in items.sorted(by: { ($0.begin, $0.end, $0.id) < ($1.begin, $1.end, $1.id) }) {
            if !groups.isEmpty, item.begin <= currentEnd {
                groups[groups.count - 1].append(item)
                currentEnd = max(currentEnd, item.end)
            } else {
                groups.append([item])
                currentEnd = item.end
            }
        }
        return groups.map(ConflictGroup.init)
    }

    public static func conflictKey(_ group: ConflictGroup) -> [String] {
        group.items.map { selectionKey($0.course) }.sorted()
    }

    public static func selectionKey(_ course: TheoryCourse) -> String { course.id }
}

public struct ScheduleIndex: Sendable {
    public let occurrences: [CourseOccurrence]
    public let dayBlocks: [DayBlock]
    public let examBlocks: [ExamBlock]
    private let byWeek: [Int: [CourseOccurrence]]
    private let blocksByWeek: [Int: [DayBlock]]
    private let examsByWeek: [Int: [ExamBlock]]

    public init(occurrences: [CourseOccurrence], dayBlocks: [DayBlock] = [], examBlocks: [ExamBlock] = []) {
        self.occurrences = occurrences
        self.dayBlocks = dayBlocks
        self.examBlocks = examBlocks
        self.byWeek = Dictionary(grouping: occurrences, by: \.week)
        self.blocksByWeek = Dictionary(grouping: dayBlocks, by: \.week)
        self.examsByWeek = Dictionary(grouping: examBlocks, by: \.week)
    }

    public func examBlocks(inWeek week: Int, weekday: Int) -> [ExamBlock] { (examsByWeek[week] ?? []).filter { $0.weekday == weekday } }

    public func dayBlocks(inWeek week: Int) -> [DayBlock] { blocksByWeek[week] ?? [] }

    public func items(inWeek week: Int) -> [CourseOccurrence] { byWeek[week] ?? [] }
    public func items(inWeek week: Int, weekday: Int) -> [CourseOccurrence] { items(inWeek: week).filter { $0.weekday == weekday } }
    public var maxWeek: Int { byWeek.keys.max() ?? 0 }
}
