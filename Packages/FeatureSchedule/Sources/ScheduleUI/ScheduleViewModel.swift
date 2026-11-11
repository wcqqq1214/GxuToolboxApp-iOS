import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage
import Observation
import ScheduleKit

@MainActor @Observable
final class ScheduleViewModel {
    enum Phase: Equatable {
        case needsLogin
        case loading
        case content
        case failed(String)
    }

    private struct LayerRequest: Equatable {
        let generation: Int
        let studentId: String
        let term: AcademicTerm
        let username: String?
    }

    private struct IndexInputs: Equatable {
        let term: AcademicTerm?
        let calendar: TermCalendar
        let schedule: Schedule
        let activities: [CustomActivity]
        let overrides: [OccurrenceOverride]
        let timeShift: [ShiftRule]
        let holidays: [HolidayRange]
    }

    struct RescheduleRequest: Hashable {
        let generation: Int
        let term: AcademicTerm
        let updatedAt: Date
    }

    private(set) var phase: Phase = .loading
    private(set) var term: AcademicTerm?
    private(set) var termCalendar: TermCalendar?
    private(set) var index = ScheduleIndex(occurrences: [])
    private(set) var colors: [String: UInt32] = [:]
    private(set) var schedule: Schedule?
    private(set) var updatedAt: Date?
    private(set) var availableTerms: [AcademicTerm] = []
    private(set) var refreshError: GxuError?
    private(set) var isRefreshing = false
    private(set) var isStatic = false
    private(set) var campusCalendar: CampusCalendar = .empty
    private(set) var choices: [String: String] = [:]
    private(set) var activities: [CustomActivity] = []
    private(set) var exams: [GridExam] = []
    @ObservationIgnored var layersProvider: ScheduleExtraLayersProvider?
    @ObservationIgnored var onCustomActivitiesChanged: (@MainActor (AppServices) async -> Void)?
    private(set) var overrides: [OccurrenceOverride] = []
    private(set) var attendance: AttendanceIndex?
    private var attendanceMarks: [AttendanceMark] = []
    private var rescheduledSlots: [String: Set<CourseReschedule.Slot>] = [:]

    var selectedWeek = 1
    var palette: CoursePalette = .macaron

    @ObservationIgnored private var services: AppServices?
    @ObservationIgnored private var studentId: String?
    @ObservationIgnored private var jwSessionID: UUID?
    @ObservationIgnored private var unifiedUsername: String?
    @ObservationIgnored private var startDays: [TermStartDay] = []
    @ObservationIgnored private var pinnedTerm: AcademicTerm?
    @ObservationIgnored private var lastRefreshStartedAt: Date?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var refreshingGeneration: Int?
    @ObservationIgnored private var layerLoad: (request: LayerRequest, task: Task<Void, Never>)?
    @ObservationIgnored private var indexInputs: IndexInputs?
    private let refreshCoordinator: ScheduleRefreshCoordinator

    init(refreshCoordinator: ScheduleRefreshCoordinator = ScheduleRefreshCoordinator()) {
        self.refreshCoordinator = refreshCoordinator
    }

    var weekCount: Int { max(termCalendar?.weekCount ?? 1, index.maxWeek, 1) }
    var currentWeek: Int { termCalendar?.clampedWeek(at: .now) ?? 1 }
    var isViewingCurrentWeek: Bool {
        if isStatic, let termCalendar, termCalendar.week(containing: .now) < 1 || termCalendar.isEnded(at: .now) { return true }
        return selectedWeek == currentWeek
    }

    func subtitle(now: Date = .now) -> String {
        guard let termCalendar else { return "" }
        if isStatic { return weekRangeText(selectedWeek) }
        if !termCalendar.isStarted(at: now) {
            let days = termCalendar.calendar.dateComponents([.day], from: termCalendar.calendar.startOfDay(for: now), to: termCalendar.startDate).day ?? 0
            return "距开学还有 \(days) 天"
        }
        if termCalendar.isEnded(at: now) { return "本学期已结束" }
        return weekRangeText(selectedWeek)
    }

    func makeupDays(inWeek week: Int) -> Set<Int> {
        Set(index.items(inWeek: week).filter(\.isMakeup).map(\.weekday))
    }

    func practiceCourses(inWeek week: Int) -> [PracticeCourse] {
        (schedule?.practiceList ?? []).filter { course in
            let weeks = WeekParser.parse(course.time)
            return weeks.isEmpty || weeks.contains(week)
        }
    }

    func weekRangeText(_ week: Int) -> String {
        guard let termCalendar else { return "" }
        let style = Date.FormatStyle(calendar: termCalendar.calendar, timeZone: termCalendar.calendar.timeZone).month(.defaultDigits).day()
        let (from, to) = (termCalendar.date(week: week, weekday: 1), termCalendar.date(week: week, weekday: 7))
        return "\(from.formatted(style)) – \(to.formatted(style))"
    }


    func load(services: AppServices) async {
        self.services = services
        let accounts = services.accounts
        guard accounts.states[.jw] != .noAccount, let studentId = accounts.studentId else {
            reset()
            phase = .needsLogin
            return
        }
        if studentId != self.studentId || jwSessionID != accounts.jwSessionID { reset() }
        self.studentId = studentId
        jwSessionID = accounts.jwSessionID
        if unifiedUsername != accounts.unifiedUsername {
            cancelLayerLoad()
            unifiedUsername = accounts.unifiedUsername
            overrides = []
            rebuildIndex()
        }

        let gen = generation
        let repository = makeRepository(services)
        let cachedDays = (try? await repository.cachedStartDays()) ?? []
        guard gen == generation else { return }
        updateStartDays(cachedDays)
        let campus = await CampusCalendarRepository(database: services.database).current()
        guard gen == generation else { return }
        campusCalendar = campus
        await applyTerm(repository: repository, studentId: studentId, generation: gen)
        guard gen == generation else { return }
        await reloadExams(generation: gen)
        guard gen == generation else { return }
        await refresh(force: false)
    }

    func loadStatic(schedule: Schedule, termCalendar: TermCalendar, campus: CampusCalendar) {
        self.schedule = schedule
        self.termCalendar = termCalendar
        self.campusCalendar = campus
        activities = []
        choices = [:]
        rebuildIndex()
        recolor()
        selectedWeek = termCalendar.week(containing: .now) >= 1 && !termCalendar.isEnded(at: .now) ? termCalendar.clampedWeek(at: .now) : 1
        isStatic = true
        phase = .content
    }

    func refreshIfDue(minimumInterval: TimeInterval = 30) async {
        guard phase == .content else { return }
        if let lastRefreshStartedAt, Date.now.timeIntervalSince(lastRefreshStartedAt) < minimumInterval { return }
        await refresh(force: false)
    }

    func refresh(force: Bool = true) async {
        guard let services, let studentId, jwSessionID == services.accounts.jwSessionID,
              refreshingGeneration != generation else { return }
        let gen = generation
        refreshingGeneration = gen
        isRefreshing = true
        lastRefreshStartedAt = .now
        defer {
            if refreshingGeneration == gen {
                refreshingGeneration = nil
                isRefreshing = false
            }
        }
        let repository = makeRepository(services)
        let campusRefresh = Task { try? await refreshCoordinator.refreshCampusCalendar(database: services.database, force: force) }
        defer {
            Task { @MainActor in
                if let updated = await campusRefresh.value, gen == generation, updated != campusCalendar {
                    campusCalendar = updated
                    rebuildIndex()
                }
            }
        }
        do {
            let fetchedStartDays = try await refreshCoordinator.refreshStartDays(services: services, studentId: studentId, force: force)
            guard gen == generation else { return }
            updateStartDays(fetchedStartDays)
            let previous = term
            guard let target = resolvedTerm, let calendar = calendar(for: target) else {
                throw GxuError.invalidData("暂时无法获取学期信息")
            }
            let fresh = try await refreshCoordinator.refreshSchedule(services: services, studentId: studentId, term: target, force: force)
            guard !Task.isCancelled, gen == generation else { return }
            if previous != target {
                let newChoices = await repository.conflictChoices(studentId: studentId, term: target)
                let newActivities = await repository.customActivities(studentId: studentId, term: target)
                guard !Task.isCancelled, gen == generation else { return }
                choices = newChoices
                activities = newActivities
            }
            setTerm(target, calendar: calendar)
            apply(fresh, resetWeek: previous != target)
            refreshError = nil
            await reloadExams(generation: gen)
        } catch {
            if error.isCancellation || Task.isCancelled || gen != generation { return }
            let gxu = (error as? GxuError) ?? .network(error.localizedDescription)
            refreshError = gxu
            if schedule == nil { phase = .failed(gxu.userMessage) }
        }
    }

    private func reloadExams(generation gen: Int, afterCacheWrite: Bool = false) async {
        guard !Task.isCancelled, gen == generation, let layersProvider, let services, let studentId, let term,
              services.accounts.studentId == studentId else { return }
        let request = LayerRequest(generation: gen, studentId: studentId, term: term, username: services.accounts.unifiedUsername)
        if !afterCacheWrite, let layerLoad, layerLoad.request == request {
            await layerLoad.task.value
            return
        }
        cancelLayerLoad()
        let task = Task { [weak self] in
            let layers = await layersProvider(request.studentId, request.term)
            guard !Task.isCancelled, let self else { return }
            self.layerLoad = nil
            guard self.generation == request.generation, self.term == request.term,
                  self.services?.accounts.studentId == request.studentId,
                  self.services?.accounts.unifiedUsername == request.username else { return }
            self.applyLayers(layers)
        }
        layerLoad = (request, task)
        await task.value
    }

    func refreshExamLayer(afterCacheWrite: Bool = false) async {
        await reloadExams(generation: generation, afterCacheWrite: afterCacheWrite)
    }

    var rescheduleRequest: RescheduleRequest? {
        guard phase == .content, let term, let updatedAt else { return nil }
        return RescheduleRequest(generation: generation, term: term, updatedAt: updatedAt)
    }

    func loadRescheduleBadges(for request: RescheduleRequest) async {
        guard let services, let studentId, let jwSessionID, !Task.isCancelled, request == rescheduleRequest,
              services.accounts.studentId == studentId, services.accounts.jwSessionID == jwSessionID else { return }
        let repository = makeRepository(services)
        let classIDs = Set(schedule?.theoryList.compactMap(\.rescheduleClassId) ?? [])
        for classId in classIDs.sorted() {
            let records = try? await repository.reschedules(classId: classId)
            guard !Task.isCancelled, request == rescheduleRequest, services.accounts.studentId == studentId,
                  services.accounts.jwSessionID == jwSessionID else { return }
            if let records { rescheduledSlots[classId] = Set(records.flatMap(\.after.slots)) }
        }
    }

    func showsRescheduleBadge(for occurrence: CourseOccurrence) -> Bool {
        guard let classId = occurrence.course.rescheduleClassId, let slots = rescheduledSlots[classId] else { return false }
        let week = occurrence.shiftedFrom.flatMap { termCalendar?.week(containing: $0) } ?? occurrence.week
        return slots.contains(.init(week: week, weekday: occurrence.course.weekday, sections: occurrence.begin...occurrence.end))
    }

    private func cancelLayerLoad() {
        layerLoad?.task.cancel()
        layerLoad = nil
    }

    private func applyLayers(_ layers: ScheduleExtraLayers) {
        let examsChanged = exams != layers.exams
        let overridesChanged = overrides != layers.overrides
        let attendanceChanged = attendanceMarks != layers.attendance
        if examsChanged { exams = layers.exams }
        if overridesChanged { overrides = layers.overrides }
        if attendanceChanged { attendanceMarks = layers.attendance }
        if overridesChanged {
            rebuildIndex()
            return
        }
        guard schedule != nil, let termCalendar else { return }
        if examsChanged {
            index = ScheduleIndex(occurrences: index.occurrences, dayBlocks: index.dayBlocks,
                                  examBlocks: ExamPlacement.blocks(for: exams, term: termCalendar))
        }
        if attendanceChanged { rebuildAttendance(calendar: termCalendar.calendar) }
    }

    func save(_ activity: CustomActivity) async {
        guard let services, let studentId, let term else { return }
        let gen = generation
        guard (try? await makeRepository(services).saveCustomActivity(activity, studentId: studentId, term: term)) != nil,
              gen == generation, self.term == term, services.accounts.studentId == studentId else { return }
        if let i = activities.firstIndex(where: { $0.id == activity.id }) { activities[i] = activity } else { activities.append(activity) }
        await activitiesChanged(services: services, term: term)
    }

    func delete(_ activity: CustomActivity) async {
        guard let services, let studentId, let term else { return }
        let gen = generation
        guard (try? await makeRepository(services).deleteCustomActivity(id: activity.id, studentId: studentId, term: term)) != nil,
              gen == generation, self.term == term, services.accounts.studentId == studentId else { return }
        activities.removeAll { $0.id == activity.id }
        await activitiesChanged(services: services, term: term)
    }

    func activity(id: String?) -> CustomActivity? { id.flatMap { id in activities.first { $0.id == id } } }

    func recolor() {
        guard schedule != nil else { return }
        colors = CourseColorAssigner.assign(courses: mergedSchedule?.theoryList.filter(\.isValid) ?? [], palette: palette, custom: customColors)
    }

    private func activitiesChanged(services: AppServices, term: AcademicTerm) async {
        activities.sort { ($0.weekFrom, $0.weekday, $0.begin, $0.id) < ($1.weekFrom, $1.weekday, $1.begin, $1.id) }
        rebuildIndex()
        recolor()
        if TermResolver.current(in: startDays, now: .now)?.academicTerm == term {
            await onCustomActivitiesChanged?(services)
        }
    }

    private var customColors: [String: UInt32] {
        Dictionary(activities.map { ($0.name, $0.colorHex) }, uniquingKeysWith: { first, _ in first })
    }

    private var mergedSchedule: Schedule? {
        guard var merged = schedule else { return nil }
        merged.theoryList += activities.filter(\.isValid).map(\.course)
        return merged
    }

    func choose(_ occurrence: CourseOccurrence, in group: ConflictGroup) async {
        guard let services, let studentId, let term else { return }
        let key = ScheduleExpander.selectionKey(occurrence.course)
        choices[group.key] = key
        publishWidgetSnapshot()
        try? await makeRepository(services).setConflictChoice(key, groupKey: group.key, studentId: studentId, term: term)
    }

    func select(term: AcademicTerm) async {
        guard let services, let studentId, term != self.term else { return }
        cancelLayerLoad()
        generation += 1
        pinnedTerm = term
        schedule = nil
        index = ScheduleIndex(occurrences: [])
        indexInputs = nil
        updatedAt = nil
        phase = .loading
        let gen = generation
        await applyTerm(repository: makeRepository(services), studentId: studentId, generation: gen)
        guard gen == generation else { return }
        await reloadExams(generation: gen)
        guard gen == generation else { return }
        await refresh(force: false)
    }


    private func makeRepository(_ services: AppServices) -> ScheduleRepository {
        ScheduleRepository(backend: services.backend, database: services.database)
    }

    private func reset() {
        cancelLayerLoad()
        generation += 1
        phase = .loading
        term = nil
        termCalendar = nil
        schedule = nil
        updatedAt = nil
        index = ScheduleIndex(occurrences: [])
        indexInputs = nil
        colors = [:]
        choices = [:]
        activities = []
        exams = []
        overrides = []
        attendanceMarks = []
        attendance = nil
        rescheduledSlots = [:]
        refreshError = nil
        pinnedTerm = nil
        studentId = nil
        jwSessionID = nil
        unifiedUsername = nil
    }

    private func updateStartDays(_ days: [TermStartDay]) {
        startDays = days
        availableTerms = days.map(\.academicTerm).sorted(by: >)
    }

    private var resolvedTerm: AcademicTerm? {
        pinnedTerm ?? TermResolver.current(in: startDays, now: .now)?.academicTerm ?? term
    }

    private func calendar(for term: AcademicTerm) -> TermCalendar? {
        startDays.first { $0.academicTerm == term }.flatMap { TermCalendar($0) }
    }

    private func setTerm(_ target: AcademicTerm, calendar: TermCalendar?) {
        if term != target {
            cancelLayerLoad()
            exams = []
            overrides = []
            attendanceMarks = []
            attendance = nil
            rescheduledSlots = [:]
        }
        term = target
        termCalendar = calendar
    }

    private func applyTerm(repository: ScheduleRepository, studentId: String, generation gen: Int) async {
        guard let target = resolvedTerm else { return }
        let previous = term
        let calendar = calendar(for: target)
        let cached = try? await repository.cachedSchedule(studentId: studentId, term: target)
        guard !Task.isCancelled, gen == generation, resolvedTerm == target, cached != nil || schedule == nil else { return }
        let newChoices = await repository.conflictChoices(studentId: studentId, term: target)
        let newActivities = await repository.customActivities(studentId: studentId, term: target)
        guard !Task.isCancelled, gen == generation, resolvedTerm == target else { return }
        setTerm(target, calendar: calendar)
        choices = newChoices
        activities = newActivities
        if let cached { apply(cached, resetWeek: previous != target) }
    }

    private func apply(_ cached: CachedSchedule, resetWeek: Bool) {
        schedule = cached.schedule
        updatedAt = cached.updatedAt
        guard let termCalendar else {
            phase = .failed("暂时无法获取学期开始日，请下拉刷新重试")
            return
        }
        if rebuildIndex() {
            recolor()
        } else {
            publishWidgetSnapshot()
        }
        if resetWeek { selectedWeek = termCalendar.clampedWeek(at: .now) }
        selectedWeek = min(max(selectedWeek, 1), weekCount)
        phase = .content
    }

    @discardableResult
    private func rebuildIndex() -> Bool {
        guard let schedule, let termCalendar else { return false }
        let inputs = IndexInputs(term: term, calendar: termCalendar, schedule: schedule, activities: activities, overrides: overrides,
                                 timeShift: campusCalendar.timeShift, holidays: campusCalendar.holidays)
        guard indexInputs != inputs, let merged = mergedSchedule else { return false }
        let base = OccurrenceOverrides.apply(overrides, to: ScheduleExpander.occurrences(of: merged, in: termCalendar))
        let overlaid = CalendarOverlay.apply(to: base, calendar: campusCalendar, term: termCalendar)
        rebuildAttendance(calendar: termCalendar.calendar)
        index = ScheduleIndex(occurrences: overlaid.occurrences, dayBlocks: overlaid.dayBlocks, examBlocks: ExamPlacement.blocks(for: exams, term: termCalendar))
        indexInputs = inputs
        publishWidgetSnapshot()
        return true
    }

    private func rebuildAttendance(calendar: Calendar) {
        attendance = attendanceMarks.isEmpty ? nil : AttendanceIndex(attendanceMarks, calendar: calendar)
    }

    private func publishWidgetSnapshot() {
        let now = Date.now
        guard let services, let studentId, let term, services.accounts.studentId == studentId,
              TermResolver.current(in: startDays, now: now)?.academicTerm == term else { return }
        let snapshot: NextCourses
        if schedule == nil {
            snapshot = .empty(.missingSchedule, now: now)
        } else if let termCalendar {
            let occurrences = ConflictResolver.resolve(index.occurrences, choices: choices)
            snapshot = NextCourseCalculator.compute(occurrences: occurrences, now: now, calendar: termCalendar.calendar)
        } else {
            snapshot = .empty(.missingStartDay, now: now)
        }
        services.shared.set(snapshot, for: ScheduleKit.widgetSnapshotKey(studentId: studentId))
    }
}
