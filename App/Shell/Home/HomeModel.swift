import CampusKit
import ClassWidgetKit
import ExamKit
import FeatureCampus
import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage
import Observation
import ScheduleKit

@MainActor @Observable
final class HomeModel {
    enum Phase: Equatable {
        case needsLogin
        case loading
        case ready
        case unavailable(String)
    }

    private struct CacheScope: Equatable {
        let database: ObjectIdentifier
        let session: UUID
        let studentId: String
        let username: String?
        let day: Date

        @MainActor init?(services: AppServices) {
            let accounts = services.accounts
            guard accounts.states[.jw] != .noAccount, let studentId = accounts.studentId else { return nil }
            database = ObjectIdentifier(services.database)
            session = accounts.jwSessionID
            self.studentId = studentId
            username = accounts.unifiedUsername
            day = Calendar.current.startOfDay(for: .now)
        }
    }

    @MainActor
    private final class CacheState {
        let scope: CacheScope
        let observation: HomeCacheObservation
        var loadedRevision: HomeCacheObservation.Revision?
        var reading: Task<Void, Never>?
        var refreshing = false

        init(scope: CacheScope, database: AppDatabase) {
            self.scope = scope
            observation = HomeCacheObservation(database: database)
        }
    }

    private(set) var phase: Phase = .loading
    private(set) var snapshot: ScheduleSnapshot?
    private var campus = CampusCalendar.empty
    private var upcomingExams: [ExamItem] = []
    private(set) var colors: [String: UInt32] = [:]
    private(set) var isRefreshing = false

    @ObservationIgnored private var throttle = RefreshThrottle()
    @ObservationIgnored private var cache: CacheState?
    private let refreshCoordinator: ScheduleRefreshCoordinator

    init(refreshCoordinator: ScheduleRefreshCoordinator = ScheduleRefreshCoordinator()) {
        self.refreshCoordinator = refreshCoordinator
    }

    func exams(at now: Date) -> [ExamItem] {
        Array(upcomingExams.lazy.filter { ($0.endsAt ?? .distantPast) > now }.prefix(3))
    }

    func hasNextEvent(now: Date = .now) -> Bool {
        nextEvent(now: now) != nil
    }

    func nextEvent(now: Date = .now) -> HomeEvent? {
        HomeEvent.pick(snapshot: snapshot, campus: campus, exams: exams(at: now), now: now)
    }

    func observeCache(services: AppServices) async {
        guard !Task.isCancelled, let state = cacheState(services: services) else { return }
        let changes = state.observation.changes()
        await synchronizeCache(state, services: services)
        for await _ in changes {
            guard !Task.isCancelled, cache === state else { return }
            if !state.refreshing || snapshot == nil || state.observation.hasInteractiveChange(since: state.loadedRevision) {
                await synchronizeCache(state, services: services)
            }
        }
    }

    func reloadFromCache(services: AppServices) async {
        guard !Task.isCancelled, let state = cacheState(services: services) else { return }
        await synchronizeCache(state, services: services, force: true)
    }

    private func cacheState(services: AppServices) -> CacheState? {
        guard let scope = CacheScope(services: services) else {
            cache = nil
            snapshot = nil
            campus = .empty
            upcomingExams = []
            colors = [:]
            isRefreshing = false
            phase = .needsLogin
            return nil
        }
        if let cache, cache.scope == scope { return cache }
        if let previous = cache?.scope,
           previous.database != scope.database || previous.session != scope.session ||
           previous.studentId != scope.studentId || previous.username != scope.username {
            snapshot = nil
            campus = .empty
            upcomingExams = []
            colors = [:]
            phase = .loading
        }
        isRefreshing = false
        let state = CacheState(scope: scope, database: services.database)
        cache = state
        return state
    }

    private func synchronizeCache(_ state: CacheState, services: AppServices, force: Bool = false) async {
        var force = force
        while !Task.isCancelled {
            let revision = await state.observation.currentRevision()
            guard !Task.isCancelled, cache === state, CacheScope(services: services) == state.scope else { return }
            if let reading = state.reading {
                await reading.value
            } else {
                if !force, let revision, state.loadedRevision == revision { return }
                let reading = Task {
                    await readCache(state, services: services)
                    state.loadedRevision = revision
                    state.reading = nil
                }
                state.reading = reading
                await reading.value
            }
            if revision == nil { return }
            force = false
        }
    }

    private func readCache(_ state: CacheState, services: AppServices) async {
        let studentId = state.scope.studentId
        let repository = ScheduleRepository(backend: services.backend, database: services.database)
        let overrides = await PhyExpOverrides.cached(database: services.database, unifiedUsername: state.scope.username)
        let cached = await repository.cachedSnapshot(studentId: studentId, overrides: overrides)
        let calendar = await CampusCalendarRepository(database: services.database).current()
        let exams = (try? await ExamRepository(database: services.database).allExams(studentId: studentId)) ?? []
        guard cache === state, CacheScope(services: services) == state.scope else { return }
        campus = calendar
        if let cached {
            if snapshot?.schedule.theoryList != cached.schedule.theoryList {
                colors = CourseColorAssigner.assign(courses: cached.schedule.theoryList.filter(\.isValid))
            }
            snapshot = cached
            phase = .ready
        }
        upcomingExams = NextExam.notEnded(in: exams)
    }

    func load(services: AppServices, minimumInterval: TimeInterval = 120) async {
        guard !Task.isCancelled, let state = cacheState(services: services) else { return }
        let accounts = services.accounts
        let studentId = state.scope.studentId
        let sessionID = state.scope.session
        let throttleKey = sessionID.uuidString
        let force = minimumInterval <= 0
        phase = snapshot == nil ? .loading : phase
        await synchronizeCache(state, services: services)
        guard !Task.isCancelled, cache === state, CacheScope(services: services) == state.scope,
              !state.refreshing else { return }
        guard throttle.recordRefreshStartIfDue(for: throttleKey, minimumInterval: minimumInterval) else {
            if snapshot == nil, !isRefreshing { phase = .unavailable("暂时没有本学期的课表数据") }
            return
        }
        state.refreshing = true
        isRefreshing = true
        defer {
            state.refreshing = false
            if cache === state { isRefreshing = false }
            state.observation.resume()
        }

        let campusRefresh = Task { try? await refreshCoordinator.refreshCampusCalendar(database: services.database, force: force) }
        defer { campusRefresh.cancel() }
        var failure: GxuError?
        do {
            let startDays = try await refreshCoordinator.refreshStartDays(services: services, studentId: studentId, force: force)
            if let current = TermResolver.current(in: startDays, now: .now), current.academicTerm.isBackendQueryable {
                let term = current.academicTerm
                let isFresh = snapshot.map {
                    $0.term == term && Date.now.timeIntervalSince($0.updatedAt) <= minimumInterval
                } ?? false
                if force || !isFresh {
                    try await refreshCoordinator.refreshSchedule(services: services, studentId: studentId, term: term, force: force)
                }
                guard !Task.isCancelled, accounts.studentId == studentId, accounts.jwSessionID == sessionID else { return }
                let exams = try await ExamAPI(backend: services.backend).exams(term)
                guard !Task.isCancelled, accounts.studentId == studentId, accounts.jwSessionID == sessionID else { return }
                try await ExamRepository(database: services.database).replaceExams(exams, studentId: studentId, term: term)
            }
        } catch {
            if error.isCancellation { throttle.forget(throttleKey); return }
            failure = (error as? GxuError) ?? .network(error.localizedDescription)
        }
        _ = await campusRefresh.value
        guard !Task.isCancelled, cache === state, CacheScope(services: services) == state.scope else { return }
        await synchronizeCache(state, services: services)
        guard !Task.isCancelled, cache === state, CacheScope(services: services) == state.scope else { return }
        if snapshot != nil {
            await WidgetBridge.refresh(services: services)
        } else {
            phase = .unavailable(failure?.userMessage ?? "暂时没有本学期的课表数据")
        }
    }
}
