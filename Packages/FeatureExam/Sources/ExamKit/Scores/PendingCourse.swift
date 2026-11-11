import Foundation
import GxuFoundation

public struct PendingCourse: Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var isLab: Bool
    public var courseId: String

    public init(id: String, name: String, isLab: Bool = false, courseId: String = "") {
        self.id = id
        self.name = name
        self.isLab = isLab
        self.courseId = courseId
    }

    public var displayName: String { name }

    public static func diff(selected: [PendingCourse], scoredIds: Set<String>) -> [PendingCourse] {
        let theoryCourseIds = Set(selected.filter { !$0.isLab && !$0.courseId.isEmpty }.map(\.courseId))
        return selected.filter { course in
            if scoredIds.contains(course.id) { return false }
            if course.isLab && theoryCourseIds.contains(course.courseId) { return false }
            return true
        }
    }
}

public protocol PendingCourseSource: Sendable {
    func pendingCourses(studentId: String, term: AcademicTerm, scoredClassIds: Set<String>) async -> [PendingCourse]
}
