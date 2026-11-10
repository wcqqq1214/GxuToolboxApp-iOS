import Foundation

/// 按日期覆盖某类课的教师 / 地点（RN v2.2 `buildCourseItems`：标题带“物理实验”的课，用 PEC 的实验课数据按上课日期覆盖教师和地点；
/// 课程名不变）。数据来自别的模块（FeatureCampus 的 PEC），由 Shell 转换后注入。
public struct OccurrenceOverride: Sendable, Hashable {
    /// 上课日期（当天 00:00，课表日历的时区）
    public var date: Date
    /// 课程名包含这段文字的课才会被覆盖，如 “物理实验”
    public var courseNameContains: String
    public var teacher: String?
    public var venue: String?

    public init(date: Date, courseNameContains: String, teacher: String? = nil, venue: String? = nil) {
        self.date = date
        self.courseNameContains = courseNameContains
        self.teacher = teacher
        self.venue = venue
    }
}

public enum OccurrenceOverrides {
    /// 返回新数组，不修改入参。空教师 / 空地点不覆盖（保留原值）。同一天有多条覆盖时以第一条为准。
    public static func apply(_ overrides: [OccurrenceOverride], to occurrences: [CourseOccurrence]) -> [CourseOccurrence] {
        guard !overrides.isEmpty else { return occurrences }
        var byDate: [Date: [OccurrenceOverride]] = [:]
        for override in overrides { byDate[override.date, default: []].append(override) }
        return occurrences.map { occurrence in
            guard
                let match = byDate[occurrence.date]?.first(where: { occurrence.course.courseName.contains($0.courseNameContains) })
            else { return occurrence }
            var course = occurrence.course
            if let teacher = match.teacher, !teacher.isEmpty { course.teacher = teacher }
            if let venue = match.venue, !venue.isEmpty { course.venueName = venue }
            return CourseOccurrence(
                course: course, week: occurrence.week, date: occurrence.date, startsAt: occurrence.startsAt, endsAt: occurrence.endsAt,
                weekday: occurrence.weekday, shiftedFrom: occurrence.shiftedFrom
            )
        }
    }
}
