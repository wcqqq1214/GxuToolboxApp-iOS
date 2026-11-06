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
    /// 只读展示（班级课表）：副标题始终显示日期范围，不写“已结束 / 距开学”
    private(set) var isStatic = false
    /// 节假日 / 补班数据；已经叠加到 `index` 里
    private(set) var campusCalendar: CampusCalendar = .empty
    /// 冲突组里用户选中显示哪一门：`ConflictGroup.key` → 课程 key
    private(set) var choices: [String: String] = [:]
    /// 用户自己添加的日程（已并入 `index`）
    private(set) var activities: [CustomActivity] = []
    /// 考试图层（由 Shell 注入的提供者读取，已画进 `index`）
    private(set) var exams: [GridExam] = []
    /// 读取某账号某学期的考试；没有提供者就不显示考试图层
    @ObservationIgnored var layersProvider: ScheduleExtraLayersProvider?
    /// 实验课等对教师 / 地点的覆盖
    private(set) var overrides: [OccurrenceOverride] = []

    var selectedWeek = 1
    var palette: CoursePalette = .macaron

    @ObservationIgnored private var services: AppServices?
    @ObservationIgnored private var studentId: String?
    @ObservationIgnored private var startDays: [TermStartDay] = []
    @ObservationIgnored private var pinnedTerm: AcademicTerm?
    @ObservationIgnored private var lastRefresh: Date?
    /// 账号 / 学期一变就加一。在途的刷新回来时 generation 对不上就丢弃结果，不能把上一个账号 / 学期的课表写进当前界面
    @ObservationIgnored private var generation = 0
    /// 正在刷新的是哪一代；只有“当前这一代”已经在刷新时才跳过，换了账号 / 学期要重新发起
    @ObservationIgnored private var refreshingGeneration: Int?

    var weekCount: Int { max(termCalendar?.weekCount ?? 1, index.maxWeek, 1) }
    var currentWeek: Int { termCalendar?.clampedWeek(at: .now) ?? 1 }
    var isViewingCurrentWeek: Bool {
        // 只读的往届 / 未开学学期没有“本周”，不显示回到本周按钮
        if isStatic, let termCalendar, termCalendar.week(containing: .now) < 1 || termCalendar.isEnded(at: .now) { return true }
        return selectedWeek == currentWeek
    }

    /// 副标题：日期范围，或开学 / 结束提示
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

    /// 这一周要上的实践课（`practiceList`）。周次无法解析的实践课每周都列出，宁可多显示不漏掉
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

        // 加载过程中账号可能又换了（`.task(id:)` 只会取消，不会打断已经在 await 的代码）：
        // 每次 await 之后核对 generation，旧账号的数据不能写进新账号的界面和小组件快照
        let gen = generation
        let repository = makeRepository(services)
        let cachedDays = (try? await repository.cachedStartDays()) ?? []
        guard gen == generation else { return }
        startDays = cachedDays
        let campus = await CampusCalendarRepository(database: services.database).current()
        guard gen == generation else { return }
        campusCalendar = campus
        await applyTerm(repository: repository, studentId: studentId, generation: gen, useCache: true)
        guard gen == generation else { return }
        await reloadExams(generation: gen)
        guard gen == generation else { return }
        await refresh()
    }

    /// 只读展示一份现成的课表（班级课表等）：不联网、不读写本地数据
    func loadStatic(schedule: Schedule, termCalendar: TermCalendar, campus: CampusCalendar) {
        self.schedule = schedule
        self.termCalendar = termCalendar
        self.campusCalendar = campus
        activities = []
        choices = [:]
        rebuildIndex()
        recolor()
        // 看别人的课表 / 往届学期：学期已结束或没开始时从第 1 周看起；学期进行中跳到本周
        selectedWeek = termCalendar.week(containing: .now) >= 1 && !termCalendar.isEnded(at: .now) ? termCalendar.clampedWeek(at: .now) : 1
        isStatic = true
        phase = .content
    }

    /// 回到前台时调用：距上次刷新不到 `minimumInterval` 秒就不再请求
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
        // 节假日数据与课表并行请求，失败或很慢都不影响课表：继续用缓存 / 内置备份
        let campusRefresh = Task { try? await CampusCalendarRepository(database: services.database).refresh() }
        defer {
            Task { @MainActor in
                if let updated = await campusRefresh.value, updated != campusCalendar {
                    campusCalendar = updated
                    rebuildIndex()
                }
            }
        }
        do {
            let fetchedStartDays = try await repository.refreshStartDays()
            guard gen == generation else { return }
            startDays = fetchedStartDays
            let previous = term
            resolveTerm()
            guard let term else { throw GxuError.invalidData("暂时无法获取学期信息") }
            // 学期在刷新中滚动到了新学期：这个学期的日程和冲突选择也要换成新学期的
            if previous != term {
                let newChoices = await repository.conflictChoices(studentId: studentId, term: term)
                let newActivities = await repository.customActivities(studentId: studentId, term: term)
                guard gen == generation else { return }
                choices = newChoices
                activities = newActivities
            }
            let fresh = try await repository.refreshSchedule(studentId: studentId, term: term)
            guard gen == generation else { return }
            apply(fresh, resetWeek: previous != term)
            refreshError = nil
            await reloadExams(generation: gen)
        } catch {
            // 取消不是故障：保持现有状态，不显示错误条
            if error.isCancellation || Task.isCancelled || gen != generation { return }
            let gxu = (error as? GxuError) ?? .network(error.localizedDescription)
            refreshError = gxu
            if schedule == nil { phase = .failed(gxu.userMessage) }
        }
    }

    /// 读取这个学期的考试并刷新考试图层。账号 / 学期在读取过程中变了就丢弃结果
    func reloadExams(generation gen: Int) async {
        guard let layersProvider, let studentId, let term else { return }
        let layers = await layersProvider(studentId, term)
        guard gen == generation else { return }
        exams = layers.exams
        overrides = layers.overrides
        rebuildIndex()
    }

    /// 课表页出现 / 回前台时重读考试图层（首页或考试页可能刚刚刷新过本地缓存）
    func refreshExamLayer() async { await reloadExams(generation: generation) }

    /// 新增或修改自定义日程，立即反映到课表和小组件快照
    func save(_ activity: CustomActivity) async {
        guard let services, let studentId, let term else { return }
        try? await makeRepository(services).saveCustomActivity(activity, studentId: studentId, term: term)
        if let i = activities.firstIndex(where: { $0.id == activity.id }) { activities[i] = activity } else { activities.append(activity) }
        activitiesChanged()
    }

    func delete(_ activity: CustomActivity) async {
        guard let services, let studentId, let term else { return }
        try? await makeRepository(services).deleteCustomActivity(id: activity.id, studentId: studentId, term: term)
        activities.removeAll { $0.id == activity.id }
        activitiesChanged()
    }

    func activity(id: String?) -> CustomActivity? { id.flatMap { id in activities.first { $0.id == id } } }

    /// 换色盘后重新配色
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

    /// 教务课表 + 自定义日程
    private var mergedSchedule: Schedule? {
        guard var merged = schedule else { return nil }
        merged.theoryList += activities.filter(\.isValid).map(\.course)
        return merged
    }

    /// 冲突组里改成显示 `occurrence` 这一门，并写入本地
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
        phase = .loading
        let gen = generation
        await applyTerm(repository: makeRepository(services), studentId: studentId, generation: gen, useCache: true)
        await reloadExams(generation: gen)
        await refresh()
    }

    // MARK: 内部

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

    private func applyTerm(repository: ScheduleRepository, studentId: String, generation gen: Int, useCache: Bool) async {
        let previous = term
        resolveTerm()
        if let term {
            let newChoices = await repository.conflictChoices(studentId: studentId, term: term)
            let newActivities = await repository.customActivities(studentId: studentId, term: term)
            guard gen == generation else { return }
            choices = newChoices
            activities = newActivities
        }
        let cachedSchedule: CachedSchedule?
        if let term { cachedSchedule = try? await repository.cachedSchedule(studentId: studentId, term: term) } else { cachedSchedule = nil }
        guard gen == generation else { return }
        guard useCache, let term, let cached = cachedSchedule else {
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
        rebuildIndex()
        colors = CourseColorAssigner.assign(courses: mergedSchedule?.theoryList.filter(\.isValid) ?? [], palette: palette, custom: customColors)
        if resetWeek { selectedWeek = termCalendar.clampedWeek(at: .now) }
        selectedWeek = min(max(selectedWeek, 1), weekCount)
        phase = .content
    }

    /// 课表 + 节假日 / 补班 → 周视图用的索引
    private func rebuildIndex() {
        guard let schedule = mergedSchedule, let termCalendar else { return }
        // 先按日期覆盖实验课的教师 / 地点，再叠加假期 / 补课（补课复制出来的课带着覆盖后的教师和地点）
        let base = OccurrenceOverrides.apply(overrides, to: ScheduleExpander.occurrences(of: schedule, in: termCalendar))
        let overlaid = CalendarOverlay.apply(to: base, calendar: campusCalendar, term: termCalendar)
        index = ScheduleIndex(occurrences: overlaid.occurrences, dayBlocks: overlaid.dayBlocks, examBlocks: ExamPlacement.blocks(for: exams, term: termCalendar))
        publishWidgetSnapshot()
    }

    private func publishWidgetSnapshot() {
        guard let services, let studentId else { return }
        let snapshot = NextCourseCalculator.compute(schedule: mergedSchedule, term: termCalendar, campus: campusCalendar, choices: choices, now: .now)
        services.shared.set(snapshot, for: ScheduleKit.widgetSnapshotKey(studentId: studentId))
    }
}
