import Foundation
import ScheduleKit

struct RescheduleArrangementSummary {
    let weeks: String
    let weekday: String
    let sections: String
    let venue: String
    let teacher: String

    init(_ arrangement: CourseReschedule.Arrangement) {
        weeks = Self.content(arrangement.weeks) ?? "未提供"
        weekday = Self.content(arrangement.weekday) ?? "未提供"
        sections = Self.content(arrangement.sections) ?? "未提供"
        venue = Self.content(arrangement.venueName) ?? "未提供"
        teacher = Self.content(arrangement.teacher) ?? "未提供"
    }

    static func content(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
