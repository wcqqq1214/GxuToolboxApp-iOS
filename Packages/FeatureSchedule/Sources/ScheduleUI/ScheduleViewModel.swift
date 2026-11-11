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
    private(set) var overrides: [OccurrenceOverride] = []
    private(set) var attendance: AttendanceIndex?
    private var attendanceMarks: [AttendanceMark] = []

    var selectedWeek = 1
    var palette: CoursePalette = .macaron

    @ObservationIgnored private var services: AppServices?
    @ObservationIgnored private var studentId: String?
    @ObservationIgnored private var unifiedUsername: String?
    @ObservationIgnored private var startDays: [TermStartDay] = []
    @ObservationIgnored private var pinnedTerm: AcademicTerm?
    @ObservationIgnored private var lastRefresh: Date?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var refreshingGeneration: Int?

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
        if studentId != self.studentId { reset() }
        self.studentId = studentId
        if unifiedUsername != accounts.unifiedUsername {
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
        await refresh()
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

    func refreshIfStale(minimumInterval: TimeInterval = 30) async {
        guard phase == .content else { return }
        if let lastRefresh, Date.now.timeIntervalSince(lastRefresh) < minimumInterval { return }
        await refresh()
    }

    func refresh() async {
        guard let services, let studentId, refreshingGeneration != generation else { return }
        let gen = generation
        refreshingGeneration = gen
        isRefreshing = true
        lastRefresh = .now
        defer {
            if refreshingGeneration == gen {
                refreshingGeneration = nil
                isRefreshing = false
            }
        }
        let repository = makeRepository(services)
        let campusRefresh = Task { try? await CampusCalendarRepository(database: services.database).refresh() }
        defer {
            Task { @MainActor in
                if let updated = await campusRefresh.value, gen == generation, updated != campusCalendar {
                    campusCalendar = updated
                    rebuildIndex()
                }
            }
        }
        do {
            let fetchedStartDays = try await repository.refreshStartDays()
            guard gen == generation else { return }
            updateStartDays(fetchedStartDays)
            let previous = term
            guard let target = resolvedTerm, let calendar = calendar(for: target) else {
                throw GxuError.invalidData("暂时无法获取学期信息")
            }
            let fresh = try await repository.refreshSchedule(studentId: studentId, term: target)
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

    func reloadExams(generation gen: Int) async {
        guard let layersProvider, let services, let studentId, let term else { return }
        let username = services.accounts.unifiedUsername
        let layers = await layersProvider(studentId, term)
        guard !Task.isCancelled, gen == generation, self.term == term, services.accounts.studentId == studentId,
              services.accounts.unifiedUsername == username else { return }
        exams = layers.exams
        overrides = layers.overrides
        attendanceMarks = layers.attendance
        rebuildIndex()
    }

    func refreshExamLayer() async { await reloadExams(generation: generation) }

    func save(_ activity: CustomActivity) async {
        guard let services, let studentId, let term else { return }
        let gen = generation
        guard (try? await makeRepository(services).saveCustomActivity(activity, studentId: studentId, term: term)) != nil,
              gen == generation, self.term == term, services.accounts.studentId == studentId else { return }
        if let i = activities.firstIndex(where: { $0.id == activity.id }) { activities[i] = activity } else { activities.append(activity) }
        activitiesChanged()
    }

    func delete(_ activity: CustomActivity) async {
        guard let services, let studentId, let term else { return }
        let gen = generation
        guard (try? await makeRepository(services).deleteCustomActivity(id: activity.id, studentId: studentId, term: term)) != nil,
              gen == generation, self.term == term, services.accounts.studentId == studentId else { return }
        activities.removeAll { $0.id == activity.id }
        activitiesChanged()
    }

    func activity(id: String?) -> CustomActivity? { id.flatMap { id in activities.first { $0.id == id } } }

    func recolor() {
        guard schedule != nil else { return }
        colors = CourseColorAssigner.assign(courses: mergedSchedule?.theoryList.filter(\.isValid) ?? [], palette: palette, custom: customColors)
    }

    private func activitiesChanged() {
        activities.sort { ($0.weekFrom, $0.weekday, $0.begin, $0.id) < ($1.weekFrom, $1.weekday, $1.begin, $1.id) }
        rebuildIndex()
        recolor()
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
        generation += 1
        pinnedTerm = term
        schedule = nil
        index = ScheduleIndex(occurrences: [])
        updatedAt = nil
        phase = .loading
        let gen = generation
        await applyTerm(repository: makeRepository(services), studentId: studentId, generation: gen)
        guard gen == generation else { return }
        await reloadExams(generation: gen)
        guard gen == generation else { return }
        await refresh()
    }


    private func makeRepository(_ services: AppServices) -> ScheduleRepository {
        ScheduleRepository(backend: services.backend, database: services.database)
    }

    private func reset() {
        generation += 1
        phase = .loading
        term = nil
        termCalendar = nil
        schedule = nil
        updatedAt = nil
        index = ScheduleIndex(occurrences: [])
        colors = [:]
        choices = [:]
        activities = []
        exams = []
        overrides = []
        attendanceMarks = []
        attendance = nil
        refreshError = nil
        pinnedTerm = nil
        studentId = nil
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
            exams = []
            overrides = []
            attendanceMarks = []
            attendance = nil
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
        rebuildIndex()
        colors = CourseColorAssigner.assign(courses: mergedSchedule?.theoryList.filter(\.isValid) ?? [], palette: palette, custom: customColors)
        if resetWeek { selectedWeek = termCalendar.clampedWeek(at: .now) }
        selectedWeek = min(max(selectedWeek, 1), weekCount)
        phase = .content
    }

    private func rebuildIndex() {
        guard let schedule = mergedSchedule, let termCalendar else { return }
        let base = OccurrenceOverrides.apply(overrides, to: ScheduleExpander.occurrences(of: schedule, in: termCalendar))
        let overlaid = CalendarOverlay.apply(to: base, calendar: campusCalendar, term: termCalendar)
        attendance = attendanceMarks.isEmpty ? nil : AttendanceIndex(attendanceMarks, calendar: termCalendar.calendar)
        index = ScheduleIndex(occurrences: overlaid.occurrences, dayBlocks: overlaid.dayBlocks, examBlocks: ExamPlacement.blocks(for: exams, term: termCalendar))
        publishWidgetSnapshot()
    }

    private func publishWidgetSnapshot() {
        let now = Date.now
        guard let services, let studentId, let term, services.accounts.studentId == studentId,
              TermResolver.current(in: startDays, now: now)?.academicTerm == term else { return }
        let snapshot = NextCourseCalculator.compute(schedule: mergedSchedule, term: termCalendar, campus: campusCalendar, choices: choices, overrides: overrides, now: now)
        services.shared.set(snapshot, for: ScheduleKit.widgetSnapshotKey(studentId: studentId))
    }
}
