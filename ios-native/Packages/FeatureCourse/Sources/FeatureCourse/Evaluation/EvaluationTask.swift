import Foundation
import GxuFoundation
import GxuNetworking

/// 一门课的评教任务（`GET /jw/evaluation`）。
/// TODO(verify): 2026-11-06 真实后端返回 404 `Cannot GET /jw/evaluation`（路由没部署），所以没有真实样本；
/// 字段按 RN 的 `EvaTeacherList` 写：可能是转换后的驼峰名（`teacherName` …），也可能是教务原始字段（`jzgmc` …），两套都认。
public struct EvaluationTask: Decodable, Sendable, Hashable, Identifiable {
    public enum Status: Int, Sendable { case pending = 0, partial, done, other }

    public var teacherName: String
    public var courseName: String
    public var courseTypeName: String
    /// `未评` / `未评完` / `已评完`
    public var submitStatus: String
    public var teachingClassId: String
    public var courseId: String

    public var id: String { "\(teachingClassId)|\(courseId)|\(teacherName)" }

    public var status: Status {
        switch submitStatus {
        case "未评": .pending
        case "未评完": .partial
        case "已评完": .done
        default: .other
        }
    }

    public init(teacherName: String, courseName: String, courseTypeName: String = "", submitStatus: String, teachingClassId: String = "", courseId: String = "") {
        self.teacherName = teacherName
        self.courseName = courseName
        self.courseTypeName = courseTypeName
        self.submitStatus = submitStatus
        self.teachingClassId = teachingClassId
        self.courseId = courseId
    }

    private enum CodingKeys: String, CodingKey {
        case teacherName, courseName, courseTypeName, submitStatus, teachingClassId, courseId
        case jzgmc, kcmc, xsmc, tjztmc, jxb_id, kch_id
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ a: CodingKeys, _ b: CodingKeys) -> String {
            ((try? c.decodeIfPresent(String.self, forKey: a)) ?? nil) ?? ((try? c.decodeIfPresent(String.self, forKey: b)) ?? nil) ?? ""
        }
        teacherName = text(.teacherName, .jzgmc)
        courseName = text(.courseName, .kcmc)
        courseTypeName = text(.courseTypeName, .xsmc)
        submitStatus = text(.submitStatus, .tjztmc)
        teachingClassId = text(.teachingClassId, .jxb_id)
        courseId = text(.courseId, .kch_id)
    }
}

/// 未评的在前，其次未评完，已评完在最后（RN 相反，把已评完放最前；待办排前面更符合使用）。同状态保持原顺序
public struct EvaluationSummary: Equatable, Sendable {
    public var pending = 0, partial = 0, done = 0
    public var total: Int { pending + partial + done }

    public init(_ tasks: [EvaluationTask]) {
        for t in tasks {
            switch t.status {
            case .pending: pending += 1
            case .partial: partial += 1
            case .done: done += 1
            case .other: break
            }
        }
    }

    public static func sorted(_ tasks: [EvaluationTask]) -> [EvaluationTask] {
        tasks.enumerated().sorted { a, b in
            a.element.status == b.element.status ? a.offset < b.offset : a.element.status.rawValue < b.element.status.rawValue
        }.map(\.element)
    }
}

public struct EvaluationAPI: Sendable {
    /// 后端目前没有部署 `/jw/evaluation`（404）：给一句能看懂的话，而不是"请求失败"
    public static func message(for error: GxuError) -> String {
        if case .http(let status, _) = error, status == 404 {
            return "评教列表服务暂未开放（后端还没有这个接口），请先在教务系统里查看评教。"
        }
        return error.userMessage
    }

    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    /// `data` 为 null 视为空列表
    public func tasks() async throws -> [EvaluationTask] {
        try await backend.getData("/jw/evaluation", as: [EvaluationTask]?.self) ?? []
    }
}
