import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage

// 校选课修读进度：RN v2.2 `src/features/electiveStrategy`（`GET /jw/elective-progress`，由后端计算课程去重、成绩匹配和达标判断，
// 客户端只展示、只格式化数值）。模型按 RN 的 zod 校验（`schema/progress.ts`）写，校验不过按"数据格式异常"处理，和 RN 一致。
// TODO(verify): 没有这个接口的真实脱敏响应（本机试登录得到 401），字段按 RN 的 schema 和 A 的差距文档写，用构造的数据测试，后续核对。

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
        /// nil = 待核对（不是未达标）
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
    /// ISO 8601
    public var computedAt: String
    /// false = 部分课程需要核对，学分只含已确认的部分，不能判断总体是否达标
    public var complete: Bool
    public var stats: Stats
    public var requirements: [Requirement]
    public var remainingRequired: [String]
    public var courses: [Course]
    public var issues: [Issue]
    /// nil = 待核对
    public var isQualified: Bool?

    /// RN：`complete ? isQualified : null`
    public var qualified: Bool? { complete ? isQualified : nil }

    public var computedDate: Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: computedAt) ?? ISO8601DateFormatter().date(from: computedAt)
    }

    /// 某项要求是否达标：结果不完整时都是"待核对"（RN：`data.complete ? item.passed : null`）
    public func passed(_ item: Requirement) -> Bool? { complete ? item.passed : nil }
}

public enum ElectiveProgressDisplay {
    /// 移植自 RN `formatProgressRequirement`：`3 / ≥4 学分`、`40% / ≤50%`
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

    /// 通过结构校验、并且 `studentId` 等于当前账号才返回（RN 同样校验账号，不一致不写缓存）
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

/// 完整服务端结果的本地缓存，按学号隔离（RN：MMKV `elective-progress:v1:<studentId>`）
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
