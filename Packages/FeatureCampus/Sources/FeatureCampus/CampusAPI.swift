import Foundation
import GxuFoundation
import GxuNetworking
import ScheduleKit

/// 学院（后端写死的列表，不含年级）
public struct School: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
}

public struct Major: Decodable, Sendable, Hashable, Identifiable {
    public let majorId: String
    public let majorName: String
    public var id: String { majorId }
}

/// 一个教学班；自带完整的定位参数（专业、年级、班级号），年级选“全部”时也能直接查到课表
public struct ClassInfo: Decodable, Sendable, Hashable, Identifiable {
    public let schoolId: String
    public let majorId: String
    public let grade: String
    public let classId: String
    public let className: String
    public var id: String { classId }
}

/// 班级课表相关接口（后端 `/jw/schedule/*`，需要教务登录）。学期只接受逻辑学期 1 / 2。
public struct CampusAPI: Sendable {
    private let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    public func schools() async throws -> [School] {
        try await backend.getData("/jw/schedule/schools", as: [School].self)
    }

    /// 空串的 `grade` / `school` 表示“全部”，不会发给后端
    public func majors(grade: String, school: String) async throws -> [Major] {
        try await backend.getData("/jw/schedule/majors", query: Self.clean(["grade": grade, "school": school]), as: [Major].self)
    }

    public func classes(term: AcademicTerm, school: String, major: String = "", grade: String = "") async throws -> [ClassInfo] {
        try Self.requireQueryable(term)
        var query = Self.clean(["school": school, "major": major, "grade": grade])
        query["year"] = String(term.year)
        query["term"] = String(term.term)
        return try await backend.getData("/jw/schedule/class-schedules", query: query, as: [ClassInfo].self)
    }

    /// 后端解析失败（教务返回异常）时是 `null`，视为错误
    public func schedule(term: AcademicTerm, of info: ClassInfo) async throws -> Schedule {
        try Self.requireQueryable(term)
        let schedule = try await backend.getData(
            "/jw/schedule/class-schedule",
            query: ["year": String(term.year), "term": String(term.term), "major": info.majorId, "grade": info.grade, "classid": info.classId],
            as: Schedule?.self
        )
        guard let schedule else { throw GxuError.invalidData("未获取到课表数据，请确认班级与学期或稍后重试") }
        return schedule
    }

    static func clean(_ query: [String: String]) -> [String: String] { query.filter { !$0.value.isEmpty } }

    static func requireQueryable(_ term: AcademicTerm) throws {
        guard term.isBackendQueryable else { throw GxuError.invalidData("暂不支持查询\(term.displayName)") }
    }
}
