import Foundation
import GxuFoundation
import GxuNetworking

public struct EvaluationTask: Decodable, Sendable, Hashable, Identifiable {
    public enum Status: Int, Sendable { case pending = 0, partial, done, other }

    public var teacherName: String
    public var courseName: String
    public var courseTypeName: String
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
    public static func message(for error: GxuError) -> String {
        if case .http(let status, _) = error, status == 404 {
            return "评教列表服务暂未开放（后端还没有这个接口），请先在教务系统里查看评教。"
        }
        return error.userMessage
    }

    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    public func tasks() async throws -> [EvaluationTask] {
        try await backend.getData("/jw/evaluation", as: [EvaluationTask]?.self) ?? []
    }
}
