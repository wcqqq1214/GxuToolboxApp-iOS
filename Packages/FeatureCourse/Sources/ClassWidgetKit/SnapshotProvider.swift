import Foundation
import FeatureCampus
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import ScheduleKit

/// 从本地缓存（数据库）算出最新的 `NextCourses`，不联网。App、App Intent 和桥接共用。
public enum SnapshotProvider {
    public static func compute(studentId: String, database: AppDatabase, unifiedUsername: String? = nil, now: Date = .now, calendar: Calendar = .current) async -> NextCourses {
        let repo = ScheduleRepository(backend: UnavailableBackend(), database: database)
        // 用 B 提供的"小组件 / App Intent 用"的缓存快照：已叠加节假日 / 补班、用户选的冲突课程、自定义日程，和 App 里的今天一致
        // 物理实验课按上课日期换成 PEC 里的教师和地点（FeatureCampus 的本地缓存，不联网），和 App 里的今天一致
        let overrides = await PhyExpOverrides.cached(database: database, unifiedUsername: unifiedUsername, calendar: calendar)
        if let snapshot = await repo.cachedSnapshot(studentId: studentId, now: now, calendar: calendar, overrides: overrides) {
            return NextCourseCalculator.compute(
                schedule: snapshot.schedule, term: snapshot.termCalendar, campus: snapshot.campus, choices: snapshot.choices,
                overrides: overrides, now: now
            )
        }
        // 没有快照：区分是缺开学日还是缺课表
        guard let days = try? await repo.cachedStartDays(), TermResolver.current(in: days, now: now, calendar: calendar) != nil
        else { return .empty(.missingStartDay, now: now) }
        return .empty(.missingSchedule, now: now)
    }
}

extension SnapshotProvider {
    /// `day` 这天本来有没有课（含已结束的），读本地缓存，出错按"没有"
    public static func hadClasses(on day: Date, studentId: String, database: AppDatabase, unifiedUsername: String? = nil, calendar: Calendar = .current) async -> Bool {
        ((try? await ScheduleQuery.courses(on: day, studentId: studentId, database: database, unifiedUsername: unifiedUsername, calendar: calendar)) ?? []).isEmpty == false
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
