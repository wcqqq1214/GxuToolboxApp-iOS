import ExamKit
import GxuFoundation
import GxuNetworking
import GxuStorage

/// "未出分科目"：同学期已选课程里没有成绩的。先用本地缓存，缓存没有这个学期时联网取一次（失败就当没有，不打扰成绩页）。
public struct SelectedCoursePendingSource: PendingCourseSource {
    private let api: SelectedCourseAPI
    private let repo: SelectedCourseRepository

    public init(backend: any BackendAPI, database: AppDatabase) {
        api = SelectedCourseAPI(backend: backend)
        repo = SelectedCourseRepository(database: database)
    }

    public func pendingCourses(studentId: String, term: AcademicTerm, scoredClassIds: Set<String>) async -> [PendingCourse] {
        guard term.isBackendQueryable else { return [] }
        var selected = (try? await repo.list(studentId: studentId, scope: .term(term))) ?? []
        if selected.isEmpty, let remote = try? await api.list(.term(term)) {
            try? await repo.replaceTerm(remote, studentId: studentId, term: term)
            selected = remote.filter { $0.year == term.year && $0.term == term.term }
        }
        return PendingCourse.diff(
            selected: selected.map { PendingCourse(id: $0.classId, name: $0.courseName, isLab: $0.isLab) },
            scoredIds: scoredClassIds
        )
    }
}
