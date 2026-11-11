import ClassWidgetKit
import ExamKit
import FeatureCampus
import Foundation
import GxuAuth
import GxuFoundation
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
    private(set) var exams: [ExamItem] = []
    private(set) var colors: [String: UInt32] = [:]
    private(set) var isRefreshing = false

    @ObservationIgnored private var throttle = RefreshThrottle()
    @ObservationIgnored private var cacheReloadID = UUID()
    @ObservationIgnored private var displayedStudentId: String?
    @ObservationIgnored private var displayedUnifiedUsername: String?

    func hasNextEvent(now: Date = .now) -> Bool {
        guard let snapshot else { return false }
        return HomeEvent.pick(snapshot: snapshot, exams: exams, now: now) != nil
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
        let notEndedExams = (try? await ExamRepository(database: services.database).examsNotEnded(studentId: studentId, limit: 3)) ?? []
        guard !Task.isCancelled, cacheReloadID == requestID, accounts.studentId == studentId, accounts.unifiedUsername == unifiedUsername else { return }
        if let cached {
            snapshot = cached
            colors = CourseColorAssigner.assign(courses: cached.schedule.theoryList.filter(\.isValid))
            phase = .ready
        }
        exams = notEndedExams
    }

    func load(services: AppServices, minimumInterval: TimeInterval = 120) async {
        let accounts = services.accounts
        let requestedStudent = accounts.studentId
        phase = snapshot == nil ? .loading : phase
        await reloadFromCache(services: services)
        guard !Task.isCancelled, phase != .needsLogin, let studentId = requestedStudent,
              accounts.studentId == studentId else { return }
        guard throttle.recordRefreshStartIfDue(for: studentId, minimumInterval: minimumInterval) else {
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
        await reloadFromCache(services: services)
        if snapshot != nil, !Task.isCancelled, accounts.studentId == studentId {
            await WidgetBridge.refresh(services: services)
        }
        if !Task.isCancelled, accounts.studentId == studentId, snapshot == nil {
            phase = .unavailable(failure?.userMessage ?? "暂时没有本学期的课表数据")
        }
    }
}
