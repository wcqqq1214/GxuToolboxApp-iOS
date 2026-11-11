import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage

public enum AttendanceRecordCache {
    private static func key(_ studentId: String, _ year: Int, _ term: Int, _ attendanceUserId: Int?) -> SharedKey<[AttendanceRecord]> {
        SharedKey("attendance.records.v2.\(studentId).\(year).\(term).\(attendanceUserId.map(String.init) ?? "unknown")")
    }

    public static func cached(store: any SharedStore, studentId: String?, year: Int, term: Int, attendanceUserId: Int? = nil) -> [AttendanceRecord] {
        guard let studentId = clean(studentId) else { return [] }
        return store.value(key(studentId, year, term, attendanceUserId)) ?? []
    }

    @MainActor static func save(_ services: AppServices, _ records: [AttendanceRecord], year: Int, term: Int) {
        guard let studentId = clean(services.accounts.studentId) else { return }
        services.shared.set(records, for: key(studentId, year, term, services.accounts.attendance?.loginInfo?.userId))
    }

    @discardableResult
    @MainActor public static func refresh(services: AppServices, year: Int, term: Int) async -> [AttendanceRecord] {
        let studentId = clean(services.accounts.studentId)
        let attendanceUserId = services.accounts.attendance?.loginInfo?.userId
        let token = services.accounts.attendance?.token
        guard services.accounts.states[.attendance] == .authenticated, studentId != nil else { return [] }
        if let records = try? await AttendanceAPI(backend: services.backend).records(year: year, term: term),
           !Task.isCancelled, clean(services.accounts.studentId) == studentId,
           services.accounts.attendance?.loginInfo?.userId == attendanceUserId,
           services.accounts.attendance?.token == token {
            save(services, records, year: year, term: term)
        }
        return cached(store: services.shared, studentId: studentId, year: year, term: term, attendanceUserId: attendanceUserId)
    }

    private static func clean(_ id: String?) -> String? {
        guard let id = id?.trimmingCharacters(in: .whitespaces), !id.isEmpty else { return nil }
        return id
    }
}
