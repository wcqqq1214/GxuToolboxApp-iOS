import ClassWidgetKit
import ExamKit
import FeatureCampus
import Foundation
import GxuAuth
import GxuFoundation
import Observation
import ScheduleKit

/// 首页（今天）的数据：课表快照 + 近期考试。先读本地缓存，再在后台刷新；刷新失败时保留缓存。
@MainActor @Observable
final class HomeModel {
    enum Phase: Equatable {
        case needsLogin
        case loading
        case ready
        /// 本地没有课表，联网也失败了
        case unavailable(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var snapshot: ScheduleSnapshot?
    /// 最近几场未结束的考试，按开考时间升序
    private(set) var exams: [ExamItem] = []
    private(set) var colors: [String: UInt32] = [:]
    private(set) var isRefreshing = false

    /// 按账号节流：全局一个时间戳会让刚切换的新账号被上一个账号的刷新挡掉
    @ObservationIgnored private var throttle = RefreshThrottle()
    @ObservationIgnored private var reloadID = UUID()
    @ObservationIgnored private var displayedStudentId: String?
    @ObservationIgnored private var displayedUnifiedUsername: String?

    /// 现在有没有“下一件事”（附件栏要不要显示）
    func hasNextEvent(now: Date = .now) -> Bool {
        guard let snapshot else { return false }
        return HomeEvent.pick(snapshot: snapshot, exams: exams, now: now) != nil
    }

    /// 只读本地缓存，切回首页时调用（便宜）
    func reload(services: AppServices) async {
        guard !Task.isCancelled else { return }
        let requestID = UUID()
        reloadID = requestID
        let accounts = services.accounts
        guard accounts.states[.jw] != .noAccount, let studentId = accounts.studentId else {
            displayedStudentId = nil
            displayedUnifiedUsername = nil
            snapshot = nil
            exams = []
            colors = [:]
            phase = .needsLogin
            return
        }
        let unifiedUsername = accounts.unifiedUsername
        if displayedStudentId != studentId || displayedUnifiedUsername != unifiedUsername {
            displayedStudentId = studentId
            displayedUnifiedUsername = unifiedUsername
            snapshot = nil
            exams = []
            colors = [:]
            phase = .loading
        }
        let repository = ScheduleRepository(backend: services.backend, database: services.database)
        let overrides = await PhyExpOverrides.cached(database: services.database, unifiedUsername: unifiedUsername)
        let cached = await repository.cachedSnapshot(studentId: studentId, overrides: overrides)
        let upcoming = (try? await ExamRepository(database: services.database).upcomingExams(studentId: studentId, limit: 3)) ?? []
        guard !Task.isCancelled, reloadID == requestID, accounts.studentId == studentId, accounts.unifiedUsername == unifiedUsername else { return }
        if let cached {
            snapshot = cached
            colors = CourseColorAssigner.assign(courses: cached.schedule.theoryList.filter(\.isValid))
            phase = .ready
        }
        exams = upcoming
    }

    /// 缓存 → 联网刷新（开学日、课表、节假日、当前学期的考试）→ 再读缓存。`minimumInterval` 内不重复请求。
    func load(services: AppServices, minimumInterval: TimeInterval = 120) async {
        let accounts = services.accounts
        let requestedStudent = accounts.studentId
        phase = snapshot == nil ? .loading : phase
        await reload(services: services)
        guard !Task.isCancelled, phase != .needsLogin, let studentId = requestedStudent,
              accounts.studentId == studentId else { return }
        guard throttle.shouldRefresh(for: studentId, minimumInterval: minimumInterval) else {
            // 另一次刷新还在进行时不下结论，它结束后会更新状态
            if snapshot == nil, !isRefreshing { phase = .unavailable("暂时没有本学期的课表数据") }
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let repository = ScheduleRepository(backend: services.backend, database: services.database)
        let campusRefresh = Task { try? await CampusCalendarRepository(database: services.database).refresh() }
        defer { campusRefresh.cancel() }
        var failure: GxuError?
        do {
            let startDays = try await repository.refreshStartDays()
            if let current = TermResolver.current(in: startDays, now: .now), current.academicTerm.isBackendQueryable {
                let term = current.academicTerm
                // 课表刚刷新过（课表页或上次）就不重复请求
                let cached = try? await repository.cachedSchedule(studentId: studentId, term: term)
                guard !Task.isCancelled, accounts.studentId == studentId else { return }
                if cached.map({ Date.now.timeIntervalSince($0.updatedAt) > minimumInterval }) ?? true {
                    try await repository.refreshSchedule(studentId: studentId, term: term)
                }
                guard !Task.isCancelled, accounts.studentId == studentId else { return }
                let exams = try await ExamAPI(backend: services.backend).exams(term)
                guard !Task.isCancelled, accounts.studentId == studentId else { return }
                try await ExamRepository(database: services.database).replaceExams(exams, studentId: studentId, term: term)
            }
        } catch {
            if error.isCancellation { throttle.forget(studentId); return }
            failure = (error as? GxuError) ?? .network(error.localizedDescription)
        }
        _ = await campusRefresh.value
        guard !Task.isCancelled, accounts.studentId == studentId else { return }
        await reload(services: services)
        if snapshot != nil, !Task.isCancelled, accounts.studentId == studentId {
            await WidgetBridge.refresh(services: services)
        }
        if !Task.isCancelled, accounts.studentId == studentId, snapshot == nil {
            phase = .unavailable(failure?.userMessage ?? "暂时没有本学期的课表数据")
        }
    }
}
