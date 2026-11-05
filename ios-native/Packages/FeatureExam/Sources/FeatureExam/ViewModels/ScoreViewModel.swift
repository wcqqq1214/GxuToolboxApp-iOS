import Foundation
import GxuAuth
import GxuFoundation
import Observation

enum UsualScoreState: Equatable {
    case loading
    case loaded([UsualScoreItem])
    case failed(String)
}

/// 成绩：先显示本地缓存，再后台刷新。`term == nil` 表示全学年（分别请求秋、春两个学期后合并）。
@MainActor @Observable
final class ScoreViewModel {
    struct Query: Hashable {
        var year: Int
        var term: Int?
    }

    var query: Query
    private(set) var scores: [Score] = []
    private(set) var lastSyncedAt: Date?
    private(set) var isLoading = false
    private(set) var error: GxuError?
    private(set) var usual: [String: UsualScoreState] = [:]

    private let api: ScoreAPI
    private let repo: ExamRepository
    private let accounts: AccountCenter

    init(services: AppServices, query: Query? = nil) {
        self.api = ScoreAPI(backend: services.backend)
        self.repo = ExamRepository(database: services.database)
        self.accounts = services.accounts
        let initial = TermOptions.defaultTerm()
        self.query = query ?? Query(year: initial.year, term: initial.term)
    }

    func load() async {
        guard let studentId = accounts.studentId else {
            error = .notLoggedIn(.jw)
            return
        }
        let query = query
        error = nil
        isLoading = true
        defer { if self.query == query { isLoading = false } }

        await showCached(studentId: studentId, query: query)

        let terms = query.term.map { [$0] } ?? [1, 2]
        var failures: [GxuError] = []
        var succeeded = 0
        for term in terms {
            do {
                let remote = try await api.scores(AcademicTerm(year: query.year, term: term))
                guard !Task.isCancelled, self.query == query else { return }
                try await repo.replaceScores(remote, studentId: studentId, year: query.year, term: term)
                succeeded += 1
            } catch is CancellationError {
                return
            } catch {
                failures.append(asGxuError(error))
            }
        }
        guard self.query == query else { return }
        // 部分学期失败时仍用成功的部分；全部失败才报错
        if succeeded == 0, let first = failures.first { error = first }
        await showCached(studentId: studentId, query: query)
    }

    private func showCached(studentId: String, query: Query) async {
        let cached = (try? await repo.scores(studentId: studentId, year: query.year, term: query.term)) ?? []
        let synced = try? await repo.lastSyncedAt(studentId: studentId, year: query.year, term: query.term)
        guard !Task.isCancelled, self.query == query else { return }
        scores = cached
        lastSyncedAt = synced ?? nil
    }

    /// 展开一行时调用：内存 → 本地缓存 → 远端
    func loadUsual(for score: Score) async {
        if case .loaded = usual[score.id] { return }
        guard let studentId = accounts.studentId else { return }
        usual[score.id] = .loading
        if let cached = try? await repo.usualScores(studentId: studentId, scoreId: score.id) {
            usual[score.id] = .loaded(cached)
            return
        }
        do {
            let items = try await api.usualScores(year: score.year, term: score.term, id: score.id)
            try? await repo.saveUsualScores(items, studentId: studentId, scoreId: score.id)
            usual[score.id] = .loaded(items)
        } catch is CancellationError {
            usual[score.id] = nil
        } catch {
            usual[score.id] = .failed("获取平时成绩失败")
        }
    }

    var gpa: GpaResult { GpaCalculator.calculate(scores) }
}
