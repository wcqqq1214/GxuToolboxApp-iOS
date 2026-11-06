import Foundation
import GxuStorage
import ScheduleKit

/// "某一天有什么课"：App Intent 用的查询与口语化文案。
public enum ScheduleQuery {
    public static func courses(
        on day: Date, schedule: Schedule, term: TermCalendar, campus: CampusCalendar = .empty, choices: [String: String] = [:]
    ) -> [WidgetCourse] {
        let start = term.calendar.startOfDay(for: day)
        let overlaid = CalendarOverlay.apply(to: ScheduleExpander.occurrences(of: schedule, in: term), calendar: campus, term: term).occurrences
        // 冲突的课只保留用户选的那一门，否则会说"有 2 节课"而实际只能上一门
        return ConflictResolver.resolve(overlaid, choices: choices)
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
        guard let snapshot = await repo.cachedSnapshot(studentId: studentId, now: day, calendar: calendar) else {
            if let days = try? await repo.cachedStartDays(), TermResolver.current(in: days, now: day, calendar: calendar) != nil { throw Failure.noSchedule }
            throw Failure.noTermCalendar
        }
        // `snapshot.schedule` 已含自定义日程，`snapshot.choices` 是用户选的冲突课程
        return courses(on: day, schedule: snapshot.schedule, term: snapshot.termCalendar, campus: snapshot.campus, choices: snapshot.choices)
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
