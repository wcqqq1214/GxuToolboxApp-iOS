import Foundation

public struct OccurrenceOverride: Sendable, Hashable {
    public var date: Date
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
