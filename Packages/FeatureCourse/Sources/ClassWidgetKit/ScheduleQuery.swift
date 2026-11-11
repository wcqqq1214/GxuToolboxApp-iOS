import Foundation
import FeatureCampus
import GxuStorage
import ScheduleKit

public enum ScheduleQuery {
    public static func courses(
        on day: Date, schedule: Schedule, term: TermCalendar, campus: CampusCalendar = .empty, choices: [String: String] = [:],
        overrides: [OccurrenceOverride] = []
    ) -> [WidgetCourse] {
        let start = term.calendar.startOfDay(for: day)
        let base = OccurrenceOverrides.apply(overrides, to: ScheduleExpander.occurrences(of: schedule, in: term))
        let overlaid = CalendarOverlay.apply(to: base, calendar: campus, term: term).occurrences
        return ConflictResolver.resolve(overlaid, choices: choices)
            .filter { $0.date == start }
            .map { WidgetCourse($0, calendar: term.calendar) }
    }

    public enum Failure: Error, Equatable, Sendable {
        case notSignedIn, noSchedule, noTermCalendar
    }

    public static func courses(
        on day: Date, studentId: String, database: AppDatabase, unifiedUsername: String? = nil, calendar: Calendar = .current
    ) async throws -> [WidgetCourse] {
        let repo = ScheduleRepository(backend: UnavailableBackend(), database: database)
        let overrides = await PhyExpOverrides.cached(database: database, unifiedUsername: unifiedUsername, calendar: calendar)
        guard let snapshot = await repo.cachedSnapshot(studentId: studentId, now: day, calendar: calendar, overrides: overrides) else {
            if let days = try? await repo.cachedStartDays(), TermResolver.current(in: days, now: day, calendar: calendar) != nil { throw Failure.noSchedule }
            throw Failure.noTermCalendar
        }
        return courses(on: day, schedule: snapshot.schedule, term: snapshot.termCalendar, campus: snapshot.campus, choices: snapshot.choices, overrides: overrides)
    }

    public static func describe(dayName: String, courses: [WidgetCourse]) -> String {
        guard !courses.isEmpty else { return "\(dayName)没有课。" }
        let lines = courses.map { c in
            "\(c.beginTime) \(c.name)" + (c.room.isEmpty ? "" : "（\(c.room)）")
        }
        return "\(dayName)有 \(courses.count) 节课：" + lines.joined(separator: "；") + "。"
    }
}
