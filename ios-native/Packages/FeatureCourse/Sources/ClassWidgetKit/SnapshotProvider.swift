import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import ScheduleKit

/// 从本地缓存（数据库）算出最新的 `NextCourses`，不联网。App、App Intent 和桥接共用。
public enum SnapshotProvider {
    public static func compute(studentId: String, database: AppDatabase, now: Date = .now, calendar: Calendar = .current) async -> NextCourses {
        let repo = ScheduleRepository(backend: UnavailableBackend(), database: database)
        guard let days = try? await repo.cachedStartDays(),
              let start = TermResolver.current(in: days, now: now, calendar: calendar)
        else { return .empty(.missingStartDay, now: now) }
        let cached = try? await repo.cachedSchedule(studentId: studentId, term: start.academicTerm)
        // 带上节假日 / 调课，否则下一节课会漏掉补班、多出放假日的课
        let campus = await CampusCalendarRepository(database: database).current()
        return NextCourseCalculator.compute(
            schedule: cached?.schedule, term: TermCalendar(start, calendar: calendar), campus: campus, now: now
        )
    }
}

extension SnapshotProvider {
    /// `day` 这天本来有没有课（含已结束的），读本地缓存，出错按"没有"
    public static func hadClasses(on day: Date, studentId: String, database: AppDatabase, calendar: Calendar = .current) async -> Bool {
        ((try? await ScheduleQuery.courses(on: day, studentId: studentId, database: database, calendar: calendar)) ?? []).isEmpty == false
    }
}

/// 只读缓存时用：任何网络请求都失败
struct UnavailableBackend: BackendAPI {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("offline")
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("offline")
    }
}
