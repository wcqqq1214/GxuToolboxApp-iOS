import Foundation
import FeatureCampus
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import ScheduleKit

public enum SnapshotProvider {
    public static func compute(studentId: String, database: AppDatabase, unifiedUsername: String? = nil, now: Date = .now, calendar: Calendar = .current) async -> NextCourses {
        let repo = ScheduleRepository(backend: UnavailableBackend(), database: database)
        let overrides = await PhyExpOverrides.cached(database: database, unifiedUsername: unifiedUsername, calendar: calendar)
        if let snapshot = await repo.cachedSnapshot(studentId: studentId, now: now, calendar: calendar, overrides: overrides) {
            return NextCourseCalculator.compute(
                schedule: snapshot.schedule, term: snapshot.termCalendar, campus: snapshot.campus, choices: snapshot.choices,
                overrides: overrides, now: now
            )
        }
        guard let days = try? await repo.cachedStartDays(), TermResolver.current(in: days, now: now, calendar: calendar) != nil
        else { return .empty(.missingStartDay, now: now) }
        return .empty(.missingSchedule, now: now)
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
