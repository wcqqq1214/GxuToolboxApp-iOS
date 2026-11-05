import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage
import Observation
import ScheduleKit

/// 课表页的状态：先显示本地缓存，再后台刷新；刷新失败时保留缓存并标注最后更新时间。
@MainActor @Observable
final class ScheduleViewModel {
    enum Phase: Equatable {
        case needsLogin
        case loading
        case content
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var term: AcademicTerm?
    private(set) var termCalendar: TermCalendar?
    private(set) var index = ScheduleIndex(occurrences: [])
    private(set) var colors: [String: UInt32] = [:]
    private(set) var schedule: Schedule?
    private(set) var updatedAt: Date?
    private(set) var availableTerms: [AcademicTerm] = []
    /// 刷新失败的原因；有缓存时页面照常显示，只在顶部给一条非阻塞提示
    private(set) var refreshError: GxuError?
    private(set) var isRefreshing = false

    var selectedWeek = 1
    var palette: CoursePalette = .macaron

    @ObservationIgnored private var services: AppServices?
    @ObservationIgnored private var studentId: String?
    @ObservationIgnored private var startDays: [TermStartDay] = []
    @ObservationIgnored private var pinnedTerm: AcademicTerm?
    @ObservationIgnored private var lastRefresh: Date?

    var weekCount: Int { max(termCalendar?.weekCount ?? 1, index.maxWeek, 1) }
    var currentWeek: Int { termCalendar?.clampedWeek(at: .now) ?? 1 }
    var isViewingCurrentWeek: Bool { selectedWeek == currentWeek }

    /// 副标题：日期范围，或开学 / 结束提示
    func subtitle(now: Date = .now) -> String {
        guard let termCalendar else { return "" }
        if !termCalendar.isStarted(at: now) {
            let days = termCalendar.calendar.dateComponents([.day], from: termCalendar.calendar.startOfDay(for: now), to: termCalendar.startDate).day ?? 0
            return "距开学还有 \(days) 天"
        }
        if termCalendar.isEnded(at: now) { return "本学期已结束" }
        return weekRangeText(selectedWeek)
    }

    func weekRangeText(_ week: Int) -> String {
        guard let termCalendar else { return "" }
        let style = Date.FormatStyle(calendar: termCalendar.calendar, timeZone: termCalendar.calendar.timeZone).month(.defaultDigits).day()
        let (from, to) = (termCalendar.date(week: week, weekday: 1), termCalendar.date(week: week, weekday: 7))
        return "\(from.formatted(style)) – \(to.formatted(style))"
    }

    // MARK: 加载

    /// 账号变化（登录 / 退出 / 换号）时重新调用
    func load(services: AppServices) async {
        self.services = services
        let accounts = services.accounts
        guard accounts.states[.jw] != .noAccount, let studentId = accounts.studentId else {
            reset()
            phase = .needsLogin
            return
        }
        if studentId != self.studentId { reset() }
        self.studentId = studentId

        let repository = makeRepository(services)
        startDays = (try? await repository.cachedStartDays()) ?? []
        await applyTerm(repository: repository, studentId: studentId, useCache: true)
        await refresh()
    }

    /// 回到前台时调用：距上次刷新不到 `minimumInterval` 秒就不再请求
    func refreshIfStale(minimumInterval: TimeInterval = 30) async {
        guard phase == .content else { return }
        if let lastRefresh, Date.now.timeIntervalSince(lastRefresh) < minimumInterval { return }
        await refresh()
    }

    func refresh() async {
        guard let services, let studentId, !isRefreshing else { return }
        isRefreshing = true
        lastRefresh = .now
        defer { isRefreshing = false }
        let repository = makeRepository(services)
        do {
            startDays = try await repository.refreshStartDays()
            let previous = term
            resolveTerm()
            guard let term else { throw GxuError.invalidData("暂时无法获取学期信息") }
            let fresh = try await repository.refreshSchedule(studentId: studentId, term: term)
            apply(fresh, resetWeek: previous != term)
            refreshError = nil
        } catch {
            let gxu = (error as? GxuError) ?? .network(error.localizedDescription)
            refreshError = gxu
            if schedule == nil { phase = .failed(gxu.userMessage) }
        }
    }

    func select(term: AcademicTerm) async {
        guard let services, let studentId, term != self.term else { return }
        pinnedTerm = term
        schedule = nil
        phase = .loading
        await applyTerm(repository: makeRepository(services), studentId: studentId, useCache: true)
        await refresh()
    }

    // MARK: 内部

    private func makeRepository(_ services: AppServices) -> ScheduleRepository {
        ScheduleRepository(backend: services.backend, database: services.database)
    }

    private func reset() {
        phase = .loading
        term = nil
        termCalendar = nil
        schedule = nil
        updatedAt = nil
        index = ScheduleIndex(occurrences: [])
        colors = [:]
        refreshError = nil
        pinnedTerm = nil
        studentId = nil
    }

    private func resolveTerm() {
        availableTerms = startDays.map(\.academicTerm).sorted(by: >)
        if let pinnedTerm {
            term = pinnedTerm
        } else if let current = TermResolver.current(in: startDays, now: .now) {
            term = current.academicTerm
        }
        termCalendar = term.flatMap { term in
            startDays.first { $0.academicTerm == term }.flatMap { TermCalendar($0) }
        }
    }

    private func applyTerm(repository: ScheduleRepository, studentId: String, useCache: Bool) async {
        let previous = term
        resolveTerm()
        guard useCache, let term, let cached = try? await repository.cachedSchedule(studentId: studentId, term: term) else {
            if schedule == nil { phase = .loading }
            return
        }
        apply(cached, resetWeek: previous != term)
    }

    private func apply(_ cached: CachedSchedule, resetWeek: Bool) {
        schedule = cached.schedule
        updatedAt = cached.updatedAt
        guard let termCalendar else {
            // 没有开学日就无法定位周次
            phase = .failed("暂时无法获取学期开始日，请下拉刷新重试")
            return
        }
        index = ScheduleIndex(occurrences: ScheduleExpander.occurrences(of: cached.schedule, in: termCalendar))
        colors = CourseColorAssigner.assign(courses: cached.schedule.theoryList.filter(\.isValid), palette: palette)
        if resetWeek { selectedWeek = termCalendar.clampedWeek(at: .now) }
        selectedWeek = min(max(selectedWeek, 1), weekCount)
        phase = .content
        publishWidgetSnapshot()
    }

    private func publishWidgetSnapshot() {
        guard let services, let studentId else { return }
        let snapshot = NextCourseCalculator.compute(schedule: schedule, term: termCalendar, now: .now)
        services.shared.set(snapshot, for: ScheduleKit.widgetSnapshotKey(studentId: studentId))
    }
}
