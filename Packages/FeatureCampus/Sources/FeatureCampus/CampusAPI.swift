import Foundation
import GxuFoundation
import GxuNetworking
import ScheduleKit

public struct School: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
}

public struct Major: Decodable, Sendable, Hashable, Identifiable {
    public let majorId: String
    public let majorName: String
    public var id: String { majorId }
}

public struct ClassInfo: Decodable, Sendable, Hashable, Identifiable {
    public let schoolId: String
    public let majorId: String
    public let grade: String
    public let classId: String
    public let className: String
    public var id: String { classId }
}

public struct CampusAPI: Sendable {
    private let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    public func schools() async throws -> [School] {
        try await backend.getData("/jw/schedule/schools", as: [School].self)
    }

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
