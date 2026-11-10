import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import Observation

/// 已选课程：先显示本地缓存，再后台刷新；刷新失败保留缓存。
@MainActor @Observable
final class SelectedCoursesViewModel {
    var scope: SelectedCourseScope = .all
    private(set) var courses: [SelectedCourse] = []
    private(set) var years: [Int] = TermOptions.years(enrollmentYear: nil)
    private(set) var isLoading = false
    private(set) var error: GxuError?
    private var hasContext = false
    /// 每次 load 递增。下拉刷新不会被 `.task(id:)` 取消，同一范围内先发的请求可能后返回：旧响应不能覆盖新数据
    private var loadVersion = 0

    private let api: SelectedCourseAPI
    private let repo: SelectedCourseRepository
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
        api = SelectedCourseAPI(backend: services.backend)
        repo = SelectedCourseRepository(database: services.database)
    }

    func resolveYears() async {
        guard !hasContext else { return }
        hasContext = true
        years = await resolveTermContext(services: services).years
    }

    func load() async {
        guard let studentId = services.accounts.studentId else {
            error = .notLoggedIn(.jw)
            return
        }
        let scope = scope
        loadVersion += 1
        let version = loadVersion
        error = nil
        isLoading = true
        defer { if version == loadVersion { isLoading = false } }

        let cached = (try? await repo.list(studentId: studentId, scope: scope)) ?? []
        guard version == loadVersion else { return }
        courses = cached
        if case .term(let t) = scope, !t.isBackendQueryable { return }   // 后端只支持 1 / 2
        do {
            let remote = try await api.list(scope)
            guard !Task.isCancelled, version == loadVersion else { return }
            switch scope {
            case .all: try await repo.replaceAll(remote, studentId: studentId)
            case .term(let t): try await repo.replaceTerm(remote, studentId: studentId, term: t)
            }
            let stored = (try? await repo.list(studentId: studentId, scope: scope)) ?? remote
            guard version == loadVersion else { return }
            courses = stored
        } catch is CancellationError {
            return
        } catch {
            guard version == loadVersion else { return }
            self.error = asGxuError(error)
        }
    }
}

/// 按学期分组（学年、学期降序），组内保持传入顺序
struct SelectedCourseGroup: Equatable, Identifiable {
    var year: Int
    var term: Int
    var courses: [SelectedCourse]
    var id: String { "\(year)-\(term)" }
    var credits: Double { courses.reduce(0) { $0 + $1.credit } }
    var title: String { "\(year)–\(year + 1) \(term == 1 ? "秋季" : term == 2 ? "春季" : "小学期")" }

    static func group(_ courses: [SelectedCourse], matching keyword: String = "") -> [SelectedCourseGroup] {
        let key = keyword.trimmingCharacters(in: .whitespaces)
        let filtered = key.isEmpty ? courses : courses.filter {
            $0.courseName.localizedCaseInsensitiveContains(key) || $0.teacher.localizedCaseInsensitiveContains(key) || $0.system.localizedCaseInsensitiveContains(key)
        }
        let dict = Dictionary(grouping: filtered) { "\($0.year)-\($0.term)" }
        return dict.values.map { SelectedCourseGroup(year: $0[0].year, term: $0[0].term, courses: $0) }
            .sorted { ($0.year, $0.term) > ($1.year, $1.term) }
    }
}

func asGxuError(_ error: Error) -> GxuError {
    (error as? GxuError) ?? .network(error.localizedDescription)
}
