import Foundation
import GxuAuth
import GxuFoundation
import Observation

func asGxuError(_ error: Error) -> GxuError {
    (error as? GxuError) ?? .network(error.localizedDescription)
}

/// 考试信息：先显示本地缓存，再后台请求并整体替换该学期缓存。
@MainActor @Observable
final class ExamInfoViewModel {
    var term: AcademicTerm
    private(set) var sections = ExamSections(upcoming: [], past: [])
    private(set) var isLoading = false
    private(set) var error: GxuError?

    private let api: ExamAPI
    private let repo: ExamRepository
    private let accounts: AccountCenter

    init(services: AppServices, term: AcademicTerm = TermOptions.defaultTerm()) {
        self.api = ExamAPI(backend: services.backend)
        self.repo = ExamRepository(database: services.database)
        self.accounts = services.accounts
        self.term = term
    }

    var totalCount: Int { sections.upcoming.count + sections.past.count }
    var hasData: Bool { totalCount > 0 }

    /// 由 `.task(id: term)` 调用；切换学期时旧任务会被取消
    func load() async {
        guard let studentId = accounts.studentId else {
            error = .notLoggedIn(.jw)
            return
        }
        let term = term
        error = nil
        isLoading = true
        defer { if self.term == term { isLoading = false } }

        if let cached = try? await repo.exams(studentId: studentId, term: term), !Task.isCancelled, self.term == term {
            apply(cached)
        }
        do {
            let remote = try await api.exams(term)
            guard !Task.isCancelled, self.term == term else { return }
            // 远端明确返回空时也要替换缓存，避免已取消的考试继续残留
            try await repo.replaceExams(remote, studentId: studentId, term: term)
            apply(remote)
        } catch is CancellationError {
        } catch {
            if self.term == term { self.error = asGxuError(error) }
        }
    }

    private func apply(_ exams: [Exam]) {
        let now = Date.now
        sections = ExamSorting.sections(exams.map { ExamItem($0, now: now) })
    }
}
