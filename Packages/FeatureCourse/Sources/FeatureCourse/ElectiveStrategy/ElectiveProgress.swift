import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage


public struct ElectiveProgress: Codable, Sendable, Equatable {
    public enum Module: String, Codable, Sendable { case lead, entrepreneurship, art, asean, ethnic, ocean }
    public enum Status: String, Codable, Sendable { case passed, failed, pending, voided, review }

    public struct ModuleStats: Codable, Sendable, Equatable {
        public var credits: Double
        public var courseCount: Int
    }

    public struct Stats: Codable, Sendable, Equatable {
        public struct Modules: Codable, Sendable, Equatable {
            public var lead, entrepreneurship, art, asean, ethnic, ocean: ModuleStats
        }
        public var totalCredits: Double
        public var offlineCredits: Double
        public var modules: Modules
    }

    public struct Requirement: Codable, Sendable, Equatable, Identifiable {
        public enum Operator: String, Codable, Sendable { case gte, lte }
        public enum Unit: String, Codable, Sendable { case credits, courses, modules, ratio }
        public var key: String
        public var label: String
        public var actual: Double
        public var required: Double
        public var `operator`: Operator
        public var unit: Unit
        public var passed: Bool?
        public var id: String { key }
    }

    public struct Attempt: Codable, Sendable, Equatable {
        public var year: Int
        public var term: Int
        public var classId: String
        public var credit: Double?
        public var score: Double?
        public var status: Status
        public var matchedBy: String?
        public var locations: [String]
        public var teachers: [String]
        public var modules: [Module]
        public var online: Bool
    }

    public struct Course: Codable, Sendable, Equatable, Identifiable {
        public var courseId: String
        public var courseName: String
        public var classIds: [String]
        public var locations: [String]
        public var teachers: [String]
        public var modules: [Module]
        public var online: Bool?
        public var credit: Double?
        public var score: Double?
        public var status: Status
        public var counted: Bool
        public var countedCredits: Double
        public var excludedReason: String?
        public var attempts: [Attempt]
        public var id: String { courseId + "|" + classIds.joined(separator: ",") }
    }

    public struct Issue: Codable, Sendable, Equatable {
        public var code: String
        public var courseId: String
        public var classId: String
        public var message: String
    }

    public var studentId: String
    public var grade: Int
    public var ruleId: String
    public var ruleVersion: String
    public var ruleName: String
    public var computedAt: String
    public var complete: Bool
    public var stats: Stats
    public var requirements: [Requirement]
    public var remainingRequired: [String]
    public var courses: [Course]
    public var issues: [Issue]
    public var isQualified: Bool?

    public var qualified: Bool? { complete ? isQualified : nil }

    public var computedDate: Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: computedAt) ?? ISO8601DateFormatter().date(from: computedAt)
    }

    public func passed(_ item: Requirement) -> Bool? { complete ? item.passed : nil }
}

public enum ElectiveProgressDisplay {
    public static func format(_ item: ElectiveProgress.Requirement) -> String {
        func n(_ v: Double) -> String { v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : String(v) }
        let op = item.operator == .lte ? "≤" : "≥"
        if item.unit == .ratio {
            func pct(_ v: Double) -> String { n((v * 1000).rounded() / 10) }
            return "\(pct(item.actual))% / \(op)\(pct(item.required))%"
        }
        let unit = [ElectiveProgress.Requirement.Unit.credits: "学分", .courses: "门", .modules: "个"][item.unit] ?? ""
        return "\(n(item.actual)) / \(op)\(n(item.required)) \(unit)"
    }

    public static func statusLabel(_ s: ElectiveProgress.Status) -> String {
        switch s {
        case .passed: "已及格"
        case .failed: "未及格"
        case .pending: "暂无成绩"
        case .voided: "成绩作废"
        case .review: "待核对"
        }
    }
}

public struct ElectiveProgressAPI: Sendable {
    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    public func fetch(studentId: String) async throws -> ElectiveProgress {
        let result: ElectiveProgress
        do {
            result = try await backend.getData("/jw/elective-progress", as: ElectiveProgress.self)
        } catch GxuError.decoding {
            throw GxuError.invalidData("校选课进度数据格式异常，请稍后重试")
        }
        guard result.studentId == studentId else { throw GxuError.invalidData("返回结果与当前教务账号不一致，请重新登录") }
        return result
    }
}

public enum ElectiveProgressCache {
    static func key(_ studentId: String) -> SharedKey<ElectiveProgress> { SharedKey("elective-progress.v1.\(studentId)") }

    public static func load(_ store: any SharedStore, studentId: String) -> ElectiveProgress? {
        guard let value = store.value(key(studentId)), value.studentId == studentId else { return nil }
        return value
    }

    public static func save(_ store: any SharedStore, _ progress: ElectiveProgress, studentId: String) throws {
        guard progress.studentId == studentId else { throw GxuError.invalidData("校选课结果账号不匹配") }
        store.set(progress, for: key(studentId))
    }
}
