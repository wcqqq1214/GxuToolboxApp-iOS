import Foundation

public struct OccurrenceOverride: Sendable, Hashable {
    public var date: Date
    public var courseNameContains: String
    public var teacher: String?
    public var venue: String?
    public var displayName: String?

    public init(date: Date, courseNameContains: String, teacher: String? = nil, venue: String? = nil, displayName: String? = nil) {
        self.date = date
        self.courseNameContains = courseNameContains
        self.teacher = teacher
        self.venue = venue
        self.displayName = displayName
    }
}

public enum OccurrenceOverrides {
    public static func apply(_ overrides: [OccurrenceOverride], to occurrences: [CourseOccurrence]) -> [CourseOccurrence] {
        guard !overrides.isEmpty else { return occurrences }
        var byDate: [Date: [OccurrenceOverride]] = [:]
        for override in overrides { byDate[override.date, default: []].append(override) }
        return occurrences.map { occurrence in
            guard
                !occurrence.course.isCustom,
                let match = byDate[occurrence.date]?.first(where: { occurrence.course.courseName.contains($0.courseNameContains) })
            else { return occurrence }
            var course = occurrence.course
            if let teacher = match.teacher, !teacher.isEmpty { course.teacher = teacher }
            if let venue = match.venue, !venue.isEmpty { course.venueName = venue }
            let displayName = match.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return CourseOccurrence(
                course: course, week: occurrence.week, date: occurrence.date, startsAt: occurrence.startsAt, endsAt: occurrence.endsAt,
                weekday: occurrence.weekday, shiftedFrom: occurrence.shiftedFrom, manualAdjustmentID: occurrence.manualAdjustmentID,
                displayNameOverride: displayName.flatMap { $0.isEmpty ? nil : $0 } ?? occurrence.displayNameOverride
            )
        }
    }
}
