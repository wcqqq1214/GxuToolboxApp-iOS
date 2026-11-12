import CampusKit
import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import ScheduleKit

public enum SnapshotProvider {
    public static func compute(studentId: String, database: AppDatabase, unifiedUsername: String? = nil, now: Date = .now, calendar: Calendar = .current) async -> NextCourses {
        await dailySnapshot(studentId: studentId, database: database, unifiedUsername: unifiedUsername, now: now, calendar: calendar).courses
    }

    static func dailySnapshot(studentId: String, database: AppDatabase, unifiedUsername: String?, now: Date, calendar: Calendar = .current) async -> (courses: NextCourses, hasClassesToday: Bool) {
        let repo = ScheduleRepository(backend: UnavailableBackend(), database: database)
        let overrides = await PhyExpOverrides.cached(database: database, unifiedUsername: unifiedUsername, calendar: calendar)
        if let snapshot = await repo.cachedSnapshot(studentId: studentId, now: now, calendar: calendar, overrides: overrides) {
            let occurrences = ConflictResolver.resolve(snapshot.occurrences, choices: snapshot.choices)
            let calendar = snapshot.termCalendar.calendar
            let today = calendar.startOfDay(for: now)
            let courses = NextCourseCalculator.compute(occurrences: occurrences, now: now, calendar: calendar)
            return (courses, occurrences.contains { $0.date == today })
        }
        guard let days = try? await repo.cachedStartDays(), TermResolver.current(in: days, now: now, calendar: calendar) != nil
        else { return (.empty(.missingStartDay, now: now), false) }
        return (.empty(.missingSchedule, now: now), false)
    }
}

extension SnapshotProvider {
    public static func hasScheduledClasses(on day: Date, studentId: String, database: AppDatabase, unifiedUsername: String? = nil, calendar: Calendar = .current) async -> Bool {
        ((try? await ScheduleQuery.courses(on: day, studentId: studentId, database: database, unifiedUsername: unifiedUsername, calendar: calendar)) ?? []).isEmpty == false
    }
}

struct UnavailableBackend: BackendAPI {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("offline")
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("offline")
    }
}
