import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import Observation

func asGxuError(_ error: Error) -> GxuError {
    (error as? GxuError) ?? .network(error.localizedDescription)
}

@MainActor @Observable
final class ExamInfoViewModel {
    var term: AcademicTerm
    private(set) var sections = ExamSections(upcoming: [], past: [])
    private(set) var isLoading = false
    private(set) var isReady = false
    private(set) var years = TermOptions.years(enrollmentYear: nil)
    private(set) var error: GxuError?

    private let api: ExamAPI
    private let repo: ExamRepository
    private let accounts: AccountCenter
    private let services: AppServices

    init(services: AppServices, term: AcademicTerm = TermOptions.defaultTerm()) {
        self.services = services
        self.api = ExamAPI(backend: services.backend)
        self.repo = ExamRepository(database: services.database)
        self.accounts = services.accounts
        self.term = term
    }

    var totalCount: Int { sections.upcoming.count + sections.past.count }
    var hasData: Bool { totalCount > 0 }

    func resolveInitialTerm() async {
        guard !isReady else { return }
        let context = await resolveTermContext(services: services)
        term = context.term
        years = context.years
        isReady = true
    }

    func load() async {
        guard isReady else { return }
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
