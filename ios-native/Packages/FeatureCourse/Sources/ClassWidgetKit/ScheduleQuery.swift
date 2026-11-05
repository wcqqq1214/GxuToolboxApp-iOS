import Foundation
import GxuStorage
import ScheduleKit

/// "某一天有什么课"：App Intent 用的查询与口语化文案。
public enum ScheduleQuery {
    public static func courses(
        on day: Date, schedule: Schedule, term: TermCalendar
    ) -> [WidgetCourse] {
        let start = term.calendar.startOfDay(for: day)
        return ScheduleExpander.occurrences(of: schedule, in: term)
            .filter { $0.date == start }
            .map { WidgetCourse($0, calendar: term.calendar) }
    }

    public enum Failure: Error, Equatable, Sendable {
        case notSignedIn, noSchedule, noTermCalendar
    }

    /// 读本地缓存，不联网
    public static func courses(
        on day: Date, studentId: String, database: AppDatabase, calendar: Calendar = .current
    ) async throws -> [WidgetCourse] {
        let repo = ScheduleRepository(backend: UnavailableBackend(), database: database)
        guard let days = try? await repo.cachedStartDays(),
              let start = TermResolver.current(in: days, now: day, calendar: calendar),
              let term = TermCalendar(start, calendar: calendar)
        else { throw Failure.noTermCalendar }
        guard let cached = try? await repo.cachedSchedule(studentId: studentId, term: start.academicTerm) else { throw Failure.noSchedule }
        return courses(on: day, schedule: cached.schedule, term: term)
    }

    /// "今天有 3 节课：08:00 高等数学（西3-406）；……"
    public static func describe(dayName: String, courses: [WidgetCourse]) -> String {
        guard !courses.isEmpty else { return "\(dayName)没有课。" }
        let lines = courses.map { c in
            "\(c.beginTime) \(c.name)" + (c.room.isEmpty ? "" : "（\(c.room)）")
        }
        return "\(dayName)有 \(courses.count) 节课：" + lines.joined(separator: "；") + "。"
    }
}
