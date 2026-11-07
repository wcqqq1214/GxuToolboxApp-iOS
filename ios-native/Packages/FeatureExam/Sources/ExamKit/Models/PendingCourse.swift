import Foundation
import GxuFoundation

/// 已选但还没出分的课程
public struct PendingCourse: Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// 实验类课程（学时类型"实验"）
    public var isLab: Bool
    /// 课程号（kch_id），用来判断实验班是不是某门理论课自带的；空串表示未知
    public var courseId: String

    public init(id: String, name: String, isLab: Bool = false, courseId: String = "") {
        self.id = id
        self.name = name
        self.isLab = isLab
        self.courseId = courseId
    }

    public var displayName: String { name }

    /// 同学期已选课程的 `classId` 与成绩 `id`（同为教学班 jxb_id）的差集，保持已选课程的顺序。
    /// 实验班不单独列出：同课程号下有理论班时，实验是那门课的一部分，成绩并在理论课里。
    /// 没有理论班的实验课（独立设课，如大学物理实验）有自己的成绩，仍然列出。
    public static func diff(selected: [PendingCourse], scoredIds: Set<String>) -> [PendingCourse] {
        let theoryCourseIds = Set(selected.filter { !$0.isLab && !$0.courseId.isEmpty }.map(\.courseId))
        return selected.filter { course in
            if scoredIds.contains(course.id) { return false }
            if course.isLab && theoryCourseIds.contains(course.courseId) { return false }
            return true
        }
    }
}

/// "未出分科目"的数据来源。已选课程在 FeatureCourse，FeatureExam 不能反向依赖，所以用协议注入。
public protocol PendingCourseSource: Sendable {
    func pendingCourses(studentId: String, term: AcademicTerm, scoredClassIds: Set<String>) async -> [PendingCourse]
}
