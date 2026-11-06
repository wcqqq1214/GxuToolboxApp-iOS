import ExamKit
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
        /// 全部学期（累计，含小学期 `term == 0`）。为 true 时 `year` / `term` 不参与查询
        var isAll = false

        static var all: Query { Query(year: TermOptions.academicYear(), term: nil, isAll: true) }
    }

    var query: Query
    private(set) var scores: [Score] = []
    private(set) var lastSyncedAt: Date?
    private(set) var isLoading = false
    private(set) var isReady = false
    private var hasContext = false
    /// 学期选择器可选的学年（入学年份起、学制年数个，且不晚于当前学年）
    private(set) var years = TermOptions.years(enrollmentYear: nil)
    private(set) var error: GxuError?
    private(set) var usual: [String: UsualScoreState] = [:]
    /// 已选但未出分的课程（只在选了具体学期时有）
    private(set) var pending: [PendingCourse] = []
    private let pendingSource: (any PendingCourseSource)?

    private let api: ScoreAPI
    private let repo: ExamRepository
    private let accounts: AccountCenter
    private let services: AppServices

    init(services: AppServices, query: Query? = nil, pendingSource: (any PendingCourseSource)? = nil) {
        self.services = services
        self.pendingSource = pendingSource
        self.isReady = query != nil
        self.api = ScoreAPI(backend: services.backend)
        self.repo = ExamRepository(database: services.database)
        self.accounts = services.accounts
        let initial = TermOptions.defaultTerm()
        self.query = query ?? Query(year: initial.year, term: initial.term)
    }

    /// 带着学期进入（如从成绩页打开绩点计算器）时只补学年范围，不改学期
    func resolveInitialTerm() async {
        guard !hasContext else { return }
        hasContext = true
        let context = await resolveTermContext(services: services)
        years = context.years
        if !isReady {
            query = Query(year: context.term.year, term: context.term.term)
            isReady = true
        }
    }

    func load() async {
        guard isReady else { return }
        guard let studentId = accounts.studentId else {
            error = .notLoggedIn(.jw)
            return
        }
        let query = query
        error = nil
        isLoading = true
        defer { if self.query == query { isLoading = false } }

        await showCached(studentId: studentId, query: query)

        if query.isAll {
            // 全部学期：后端不带 year / term 一次返回全部历史成绩，不逐学年循环请求
            do {
                let remote = try await api.allScores()
                guard !Task.isCancelled, self.query == query else { return }
                try await repo.replaceAllScores(remote, studentId: studentId)
            } catch is CancellationError {
                return
            } catch {
                guard self.query == query else { return }
                self.error = asGxuError(error)   // 有缓存时界面保留缓存并提示，没有缓存才整页报错
            }
            guard self.query == query else { return }
            await showCached(studentId: studentId, query: query)
            pending = []
            return
        }

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
        await loadPending(studentId: studentId, query: query)
    }

    private func loadPending(studentId: String, query: Query) async {
        guard let pendingSource, !query.isAll, let term = query.term else {
            pending = []
            return
        }
        let ids = Set(scores.map(\.id))
        let list = await pendingSource.pendingCourses(studentId: studentId, term: AcademicTerm(year: query.year, term: term), scoredClassIds: ids)
        guard self.query == query else { return }
        pending = list
    }

    private func showCached(studentId: String, query: Query) async {
        let cached: [Score]
        let synced: Date?
        if query.isAll {
            cached = (try? await repo.allScores(studentId: studentId)) ?? []
            synced = (try? await repo.allLastSyncedAt(studentId: studentId)) ?? nil
        } else {
            cached = (try? await repo.scores(studentId: studentId, year: query.year, term: query.term)) ?? []
            synced = (try? await repo.lastSyncedAt(studentId: studentId, year: query.year, term: query.term)) ?? nil
        }
        guard !Task.isCancelled, self.query == query else { return }
        scores = cached
        lastSyncedAt = synced
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

    /// 绩点页用：按重修规则合并后实际计入的成绩（成绩查询页仍显示 `scores` 里的全部原始记录）
    var resolved: RetakeResolution { RetakeRule.resolve(scores) }

    var gpa: GpaResult { GpaCalculator.calculate(resolved.counted) }
}
