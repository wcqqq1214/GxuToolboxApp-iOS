import GxuAuth
import GxuFoundation
import GxuDesign
import ScheduleKit
import SwiftUI

public struct ScheduleRootView: View {
    @Environment(\.services) private var services
    @State private var model: ScheduleViewModel
    @State private var detail: ConflictGroup?
    @State private var editor: ActivityEditorRequest?
    @State private var showActivityList = false
    @State private var showShare = false
    @Environment(SchedulePreferencesStore.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @State private var examDetail: GridExam?
    private let onRequestLogin: @MainActor () -> Void
    private let layers: ScheduleExtraLayersProvider?

    private let exportDestination: (@MainActor () -> AnyView)?
    private let onCustomActivitiesChanged: (@MainActor (AppServices) async -> Void)?
    private let refreshAttendance: (@MainActor (String, AcademicTerm) async -> Void)?

    public init(onRequestLogin: @escaping @MainActor () -> Void = {}, layers: ScheduleExtraLayersProvider? = nil,
                exportDestination: (@MainActor () -> AnyView)? = nil,
                refreshCoordinator: ScheduleRefreshCoordinator = ScheduleRefreshCoordinator(),
                onCustomActivitiesChanged: (@MainActor (AppServices) async -> Void)? = nil,
                refreshAttendance: (@MainActor (String, AcademicTerm) async -> Void)? = nil) {
        _model = State(initialValue: ScheduleViewModel(refreshCoordinator: refreshCoordinator))
        self.onRequestLogin = onRequestLogin
        self.layers = layers
        self.exportDestination = exportDestination
        self.onCustomActivitiesChanged = onCustomActivitiesChanged
        self.refreshAttendance = refreshAttendance
    }

    private struct AccountKey: Hashable {
        var studentId: String?
        var sessionID: UUID
        var state: AuthState?
        var unifiedUsername: String?
    }

    private struct AttendanceKey: Hashable {
        var studentId: String?
        var term: AcademicTerm?
        var userId: Int?
        var state: AuthState?
        var isActive: Bool
    }

    private var attendanceKey: AttendanceKey {
        AttendanceKey(studentId: services.accounts.studentId, term: model.term,
                      userId: services.accounts.attendance?.loginInfo?.userId,
                      state: services.accounts.states[.attendance], isActive: scenePhase == .active)
    }

    public var body: some View {
        NavigationStack {
            content
                .gxuPageBackground()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .task(id: AccountKey(studentId: services.accounts.studentId, sessionID: services.accounts.jwSessionID, state: services.accounts.states[.jw],
                             unifiedUsername: services.accounts.unifiedUsername)) {
            model.layersProvider = layers
            model.onCustomActivitiesChanged = onCustomActivitiesChanged
            await model.load(services: services)
        }
        .task(id: attendanceKey) {
            let key = attendanceKey
            guard let refreshAttendance, key.isActive, let studentId = key.studentId, let term = key.term else { return }
            await model.refreshExamLayer()
            guard !Task.isCancelled, key.state == .authenticated, key.userId != nil else { return }
            await refreshAttendance(studentId, term)
            if !Task.isCancelled { await model.refreshExamLayer(afterCacheWrite: true) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshIfDue(); await model.refreshExamLayer() } }
        }
        .onAppear {
            model.palette = preferences.value.palette
            Task { await model.refreshExamLayer() }
        }
        .task(id: model.phase) {
            guard model.phase == .content else { return }
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { await model.refreshExamLayer() }
        }
        #if DEBUG
        .task(id: model.phase) { await debugPresentSheet() }
        #endif
        .onChange(of: preferences.value.palette) { _, palette in
            model.palette = palette
            model.recolor()
        }
        .onChange(of: services.accounts.studentId) { detail = nil }
        .sheet(item: $detail) { group in
            let studentId = services.accounts.studentId
            CourseDetailSheet(
                group: group, colors: model.colors, selected: group.selected(choices: model.choices), exams: model.exams, term: model.term, attendance: model.attendance,
                onChoose: { item in Task { await model.choose(item, in: group) } },
                onEditActivity: { id in
                    detail = nil
                    if let activity = model.activity(id: id) { editor = ActivityEditorRequest(activity: activity, isNew: false) }
                },
                loadReschedules: { classId in try await loadCourseReschedules(classId, studentId: studentId) }
            )
        }
        .sheet(item: $editor) { request in
            ActivityEditorSheet(
                activity: request.activity, isNew: request.isNew, weekCount: model.weekCount,
                termTitle: model.term.map { "\($0.year) 学年第 \($0.term) 学期" } ?? "", palette: preferences.value.palette,
                onSave: { activity in Task { await model.save(activity) } },
                onDelete: request.isNew ? nil : { Task { await model.delete(request.activity) } }
            )
        }
        .sheet(item: $examDetail) { exam in ExamDetailSheet(exam: exam) }
        .sheet(isPresented: $showShare) {
            ShareScheduleSheet(model: model, week: model.selectedWeek, preferences: preferences)
        }
        .sheet(isPresented: $showActivityList) {
            ActivityListSheet(
                activities: model.activities,
                onAdd: { showActivityList = false; addActivity() },
                onEdit: { activity in showActivityList = false; editor = ActivityEditorRequest(activity: activity, isNew: false) },
                onDelete: { activity in Task { await model.delete(activity) } }
            )
        }
    }

    private func loadCourseReschedules(_ classId: String, studentId: String?) async throws -> [CourseReschedule] {
        let accounts = services.accounts
        guard let studentId, accounts.studentId == studentId else { throw CancellationError() }
        let repository = ScheduleRepository(backend: services.backend, database: services.database)
        let records = try await repository.reschedules(classId: classId)
        guard accounts.studentId == studentId else { throw CancellationError() }
        return records
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .needsLogin:
            GxuEmptyView(
                "还没有登录教务系统", systemImage: "person.crop.circle.badge.questionmark",
                message: "登录后即可查看你的课表", actionTitle: "去登录", action: onRequestLogin
            )
        case .loading:
            GxuLoadingView("正在加载课表…")
        case .failed(let message):
            GxuErrorView(message) { Task { await model.refresh() } }
        case .content:
            ScheduleBoard(model: model, onSelect: { detail = $0 }, onSelectExam: { examDetail = $0 })
                .safeAreaInset(edge: .top, spacing: 0) {
                    if model.refreshError != nil {
                        GxuStaleBanner(updatedAt: model.updatedAt, message: model.refreshError?.userMessage)
                    }
                }
        }
    }


    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if model.phase == .content { ScheduleWeekTitle(model: model, terms: model.availableTerms, term: termBinding) }
        }
        ToolbarItem(placement: .topBarLeading) {
            if model.phase == .content {
                Menu {
                    Button("添加自定义课程", systemImage: "plus") { addActivity() }
                    Button("我的自定义课程", systemImage: "list.bullet") { showActivityList = true }
                    Divider()
                    Button("分享本周课表", systemImage: "square.and.arrow.up") { showShare = true }
                    if let exportDestination {
                        NavigationLink { exportDestination() } label: {
                            Label("导出教务课表", systemImage: "doc")
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("课表操作")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if model.phase == .content, model.isRefreshing { ProgressView() }
        }
    }

    private var termBinding: Binding<AcademicTerm> {
        Binding(
            get: { model.term ?? model.availableTerms[0] },
            set: { term in Task { await model.select(term: term) } }
        )
    }

    #if DEBUG
    private func debugPresentSheet() async {
        let args = ProcessInfo.processInfo.arguments
        guard model.phase == .content, let i = args.firstIndex(of: "-GxuScheduleSheet"), i + 1 < args.count else { return }
        switch args[i + 1] {
        case "add": addActivity()
        case "list":
            await model.save(CustomActivity(name: "光学实验", note: "带预习报告", location: "理科楼 301", teacher: "教师甲", weekday: 3, begin: 9, end: 10, weeks: [1, 2, 3, 4, 6, 8, 10], colorHex: 0xB3E5FC))
            await model.save(CustomActivity(name: "电学实验", weekday: 5, begin: 11, end: 12, weeks: [3], colorHex: 0xFFE0B2))
            showActivityList = true
        case "share": showShare = true
        case "detail":
            let week = model.selectedWeek
            if let group = ScheduleExpander.conflictGroups(model.index.items(inWeek: week, weekday: 1)).first { detail = group }
        default: break
        }
    }
    #endif

    private func addActivity() {
        let week = model.selectedWeek
        editor = ActivityEditorRequest(
            activity: CustomActivity(name: "", weekday: min(max(model.termCalendar?.weekday(of: .now) ?? 1, 1), 7), weekFrom: week, weekTo: week, colorHex: preferences.value.palette.colors.randomElement() ?? 0xB5EAD7),
            isNew: true
        )
    }
}

struct ActivityEditorRequest: Identifiable {
    let activity: CustomActivity
    let isNew: Bool
    var id: String { activity.id }
}
