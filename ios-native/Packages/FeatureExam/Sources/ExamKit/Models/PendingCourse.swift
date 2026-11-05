import Foundation
import GxuFoundation

/// 已选但还没出分的课程
public struct PendingCourse: Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// 实验类课程，展示时在课程名后加"(实验)"
    public var isLab: Bool

    public init(id: String, name: String, isLab: Bool = false) {
        self.id = id
        self.name = name
        self.isLab = isLab
    }

    public var displayName: String { isLab ? "\(name)(实验)" : name }

    /// 同学期已选课程的 `classId` 与成绩 `id`（同为教学班 jxb_id）的差集，保持已选课程的顺序
    public static func diff(selected: [PendingCourse], scoredIds: Set<String>) -> [PendingCourse] {
        selected.filter { !scoredIds.contains($0.id) }
    }
}

/// "未出分科目"的数据来源。已选课程在 FeatureCourse，FeatureExam 不能反向依赖，所以用协议注入。
public protocol PendingCourseSource: Sendable {
    func pendingCourses(studentId: String, term: AcademicTerm, scoredClassIds: Set<String>) async -> [PendingCourse]
}
