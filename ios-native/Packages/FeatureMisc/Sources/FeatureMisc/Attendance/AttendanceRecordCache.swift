import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage

/// 考勤记录的本地缓存，按学号 + 学期隔离（RN：MMKV 缓存，课表页先读缓存再静默刷新）。
/// 课表的考勤图层只读缓存，不联网；考勤页每次成功 `load()` 后写入。
public enum AttendanceRecordCache {
    private static func key(_ studentId: String, _ year: Int, _ term: Int) -> SharedKey<[AttendanceRecord]> {
        SharedKey("attendance.records.v2.\(studentId).\(year).\(term)")
    }

    /// 只读缓存；没有缓存、账号不同都返回空
    public static func cached(store: any SharedStore, studentId: String?, year: Int, term: Int) -> [AttendanceRecord] {
        guard let studentId = clean(studentId) else { return [] }
        return store.value(key(studentId, year, term)) ?? []
    }

    @MainActor static func save(_ services: AppServices, _ records: [AttendanceRecord], year: Int, term: Int) {
        guard let studentId = clean(services.accounts.studentId) else { return }
        services.shared.set(records, for: key(studentId, year, term))
    }

    /// 已登录考勤时静默刷新：成功写缓存，失败保留缓存、不报错。返回刷新后的缓存内容。
    @discardableResult
    @MainActor public static func refresh(services: AppServices, year: Int, term: Int) async -> [AttendanceRecord] {
        let studentId = clean(services.accounts.studentId)
        guard services.accounts.states[.attendance] == .authenticated, studentId != nil else {
            return cached(store: services.shared, studentId: studentId, year: year, term: term)
        }
        if let records = try? await AttendanceAPI(backend: services.backend).records(year: year, term: term),
           clean(services.accounts.studentId) == studentId {   // 期间换了账号就不写，避免串到别人的缓存
            save(services, records, year: year, term: term)
        }
        return cached(store: services.shared, studentId: studentId, year: year, term: term)
    }

    private static func clean(_ id: String?) -> String? {
        guard let id = id?.trimmingCharacters(in: .whitespaces), !id.isEmpty else { return nil }
        return id
    }
}
