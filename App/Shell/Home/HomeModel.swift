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

    private(set) var phase: Phase = .loading
    private(set) var snapshot: ScheduleSnapshot?
    private var upcomingExams: [ExamItem] = []
    private(set) var colors: [String: UInt32] = [:]
    private(set) var isRefreshing = false

    @ObservationIgnored private var throttle = RefreshThrottle()
    @ObservationIgnored private var cacheReloadID = UUID()
    @ObservationIgnored private var displayedStudentId: String?
    @ObservationIgnored private var displayedUnifiedUsername: String?
    private let refreshCoordinator: ScheduleRefreshCoordinator

    init(refreshCoordinator: ScheduleRefreshCoordinator = ScheduleRefreshCoordinator()) {
        self.refreshCoordinator = refreshCoordinator
    }

    func exams(at now: Date) -> [ExamItem] {
        Array(upcomingExams.lazy.filter { ($0.endsAt ?? .distantPast) > now }.prefix(3))
    }

    func hasNextEvent(now: Date = .now) -> Bool {
        guard let snapshot else { return false }
        return HomeEvent.pick(snapshot: snapshot, exams: exams(at: now), now: now) != nil
    }

    func observeCache(services: AppServices) async {
        guard services.accounts.studentId != nil else {
            await reloadFromCache(services: services)
            return
        }
        let regions = [
            "schedule_snapshot", "term_start_day", "campus_calendar", "schedule_conflict_choice",
            "schedule_custom_activity", "exam_info", "phy_experiment"
        ].map { Table<Row>($0) }
        let observation = ValueObservation.tracking(regions: regions) { _ in () }
        do {
            for try await _ in observation.values(in: services.database.writer, bufferingPolicy: .bufferingNewest(1)) {
                await reloadFromCache(services: services)
            }
        } catch {
            await reloadFromCache(services: services)
        }
    }

    func reloadFromCache(services: AppServices) async {
        guard !Task.isCancelled else { return }
        let requestID = UUID()
        cacheReloadID = requestID
        let accounts = services.accounts
        guard accounts.states[.jw] != .noAccount, let studentId = accounts.studentId else {
            displayedStudentId = nil
            displayedUnifiedUsername = nil
            snapshot = nil
            upcomingExams = []
            colors = [:]
            phase = .needsLogin
            return
        }
        let sessionID = accounts.jwSessionID
        let unifiedUsername = accounts.unifiedUsername
        if displayedStudentId != studentId || displayedUnifiedUsername != unifiedUsername {
            displayedStudentId = studentId
            displayedUnifiedUsername = unifiedUsername
            snapshot = nil
            upcomingExams = []
            colors = [:]
            phase = .loading
        }
        let repository = ScheduleRepository(backend: services.backend, database: services.database)
        let overrides = await PhyExpOverrides.cached(database: services.database, unifiedUsername: unifiedUsername)
        let cached = await repository.cachedSnapshot(studentId: studentId, overrides: overrides)
        let exams = (try? await ExamRepository(database: services.database).allExams(studentId: studentId)) ?? []
        guard !Task.isCancelled, cacheReloadID == requestID, accounts.studentId == studentId,
              accounts.jwSessionID == sessionID, accounts.unifiedUsername == unifiedUsername else { return }
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
        let accounts = services.accounts
        let requestedStudent = accounts.studentId
        let sessionID = accounts.jwSessionID
        let throttleKey = sessionID.uuidString
        let force = minimumInterval <= 0
        phase = snapshot == nil ? .loading : phase
        await reloadFromCache(services: services)
        guard !Task.isCancelled, phase != .needsLogin, let studentId = requestedStudent,
              accounts.studentId == studentId, accounts.jwSessionID == sessionID else { return }
        guard throttle.recordRefreshStartIfDue(for: throttleKey, minimumInterval: minimumInterval) else {
            if snapshot == nil, !isRefreshing { phase = .unavailable("暂时没有本学期的课表数据") }
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

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
        guard !Task.isCancelled, accounts.studentId == studentId, accounts.jwSessionID == sessionID else { return }
        await reloadFromCache(services: services)
        if snapshot != nil, !Task.isCancelled, accounts.studentId == studentId, accounts.jwSessionID == sessionID {
            await WidgetBridge.refresh(services: services)
        }
        if !Task.isCancelled, accounts.studentId == studentId, accounts.jwSessionID == sessionID, snapshot == nil {
            phase = .unavailable(failure?.userMessage ?? "暂时没有本学期的课表数据")
        }
    }
}
