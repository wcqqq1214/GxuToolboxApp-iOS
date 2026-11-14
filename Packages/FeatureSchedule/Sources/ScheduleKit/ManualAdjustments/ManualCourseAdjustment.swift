import Foundation

public struct ManualCourseAdjustment: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let week: Int
    public let weekday: Int
    public let begin: Int
    public let end: Int
    public let location: String

    public init(sourceID: String, week: Int, weekday: Int, begin: Int, end: Int, location: String) {
        id = sourceID
        self.week = week
        self.weekday = weekday
        self.begin = begin
        self.end = end
        self.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var validationMessage: String? {
        if id.isEmpty { return "找不到原课次，请重新打开课程详情" }
        if !(1...TermCalendar.maximumWeeks).contains(week) { return "请选择有效的教学周" }
        if !(1...7).contains(weekday) { return "请选择星期" }
        if !(1...ClassPeriods.count).contains(begin) || !(1...ClassPeriods.count).contains(end) || end < begin {
            return "请选择有效的开始和结束节次"
        }
        if location.count > 200 { return "地点最多 200 字" }
        return nil
    }

    public static func apply(_ adjustments: [Self], to occurrences: [CourseOccurrence], term: TermCalendar) -> [CourseOccurrence] {
        let byID = Dictionary(adjustments.filter { $0.validationMessage == nil }.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        return occurrences.map { original in
            guard !original.course.isCustom, let adjustment = byID[original.id],
                  let first = ClassPeriods.period(adjustment.begin), let last = ClassPeriods.period(adjustment.end) else { return original }
            let date = term.date(week: adjustment.week, weekday: adjustment.weekday)
            guard let start = term.calendar.date(bySettingHour: first.start.hour, minute: first.start.minute, second: 0, of: date),
                  let end = term.calendar.date(bySettingHour: last.end.hour, minute: last.end.minute, second: 0, of: date) else { return original }
            var course = original.course
            course.begin = adjustment.begin
            course.end = adjustment.end
            course.sectionRange = "\(adjustment.begin)-\(adjustment.end)"
            course.weekday = adjustment.weekday
            course.weeks = [adjustment.week]
            course.building = ""
            course.venueName = adjustment.location
            return CourseOccurrence(course: course, week: adjustment.week, date: date, startsAt: start, endsAt: end,
                                    weekday: adjustment.weekday, manualAdjustmentID: original.id)
        }.sorted { ($0.startsAt, $0.id) < ($1.startsAt, $1.id) }
    }
}
