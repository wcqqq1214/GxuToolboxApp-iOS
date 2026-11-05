import Foundation

/// 一门课在某一周的一次上课
public struct CourseOccurrence: Sendable, Hashable, Identifiable, Codable {
    public let course: TheoryCourse
    public let week: Int
    /// 当天 00:00
    public let date: Date
    public let startsAt: Date
    public let endsAt: Date

    public var id: String { "\(course.id)#\(week)" }
    public var weekday: Int { course.weekday }
    public var begin: Int { course.begin }
    public var end: Int { course.end }
}

/// 同一天内时段相交的一组课。`begin...end` 是组内最小开始节到最大结束节。
public struct ConflictGroup: Sendable, Hashable, Identifiable {
    public let items: [CourseOccurrence]
    public var begin: Int { items.map(\.begin).min() ?? 1 }
    public var end: Int { items.map(\.end).max() ?? 1 }
    public var id: String { items.map(\.id).joined(separator: "&") }
    public var isConflict: Bool { items.count > 1 }
}

public enum ScheduleExpander {
    /// 把整份课表按周次展开成上课记录，按开始时间升序。非法数据（星期 / 节次越界、周次 < 1）被丢弃。
    public static func occurrences(of schedule: Schedule, in term: TermCalendar) -> [CourseOccurrence] {
        let calendar = term.calendar
        var result: [CourseOccurrence] = []
        for course in schedule.theoryList where course.isValid {
            guard let first = ClassPeriods.period(course.begin), let last = ClassPeriods.period(course.end) else { continue }
            for week in Set(course.weeks) where week >= 1 {
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

    /// 同一天的课按节次区间合并（传递闭包：A∩B、B∩C 则 A、B、C 同组）。
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

    /// 冲突组的稳定标识：组内课程 key 排序后拼接，用来存“当前选中哪一门”
    public static func conflictKey(_ group: ConflictGroup) -> [String] {
        group.items.map { selectionKey($0.course) }.sorted()
    }

    /// 课程 key，与 RN 的 `courseName_teacher` 一致
    public static func selectionKey(_ course: TheoryCourse) -> String { "\(course.courseName)_\(course.teacher)" }
}

/// 按周索引，方便周视图取数
public struct ScheduleIndex: Sendable {
    public let occurrences: [CourseOccurrence]
    private let byWeek: [Int: [CourseOccurrence]]

    public init(occurrences: [CourseOccurrence]) {
        self.occurrences = occurrences
        self.byWeek = Dictionary(grouping: occurrences, by: \.week)
    }

    public func items(inWeek week: Int) -> [CourseOccurrence] { byWeek[week] ?? [] }
    public func items(inWeek week: Int, weekday: Int) -> [CourseOccurrence] { items(inWeek: week).filter { $0.weekday == weekday } }
    public var maxWeek: Int { byWeek.keys.max() ?? 0 }
}
