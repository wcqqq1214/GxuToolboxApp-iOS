import GxuAuth
import GxuFoundation
import GxuDesign
import ScheduleKit
import SwiftUI

/// 课表页：左右滑动切周，底部浮动玻璃控件（上一周 / 回到本周 / 下一周），点课程弹出详情 sheet。
public struct ScheduleRootView: View {
    @Environment(\.services) private var services
    @State private var model = ScheduleViewModel()
    @State private var detail: ConflictGroup?
    @State private var editor: ActivityEditorRequest?
    @State private var showActivityList = false
    @Environment(SchedulePreferencesStore.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var glassNamespace
    private let onRequestLogin: @MainActor () -> Void

    public init(onRequestLogin: @escaping @MainActor () -> Void = {}) {
        self.onRequestLogin = onRequestLogin
    }

    /// 账号变化时重新加载
    private struct AccountKey: Hashable {
        var studentId: String?
        var state: AuthState?
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .task(id: AccountKey(studentId: services.accounts.studentId, state: services.accounts.states[.jw])) {
            await model.load(services: services)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshIfStale() } }
        }
        .onAppear { model.palette = preferences.value.palette }
        #if DEBUG
        .task(id: model.phase) { await debugPresentSheet() }
        #endif
        .onChange(of: preferences.value.palette) { _, palette in
            model.palette = palette
            model.recolor()
        }
        .sheet(item: $detail) { group in
            CourseDetailSheet(
                group: group, colors: model.colors, selected: group.selected(choices: model.choices),
                onChoose: { item in Task { await model.choose(item, in: group) } },
                onEditActivity: { id in
                    detail = nil
                    if let activity = model.activity(id: id) { editor = ActivityEditorRequest(activity: activity, isNew: false) }
                }
            )
        }
        .sheet(item: $editor) { request in
            ActivityEditorSheet(
                activity: request.activity, isNew: request.isNew, weekCount: model.weekCount, palette: preferences.value.palette,
                onSave: { activity in Task { await model.save(activity) } },
                onDelete: request.isNew ? nil : { Task { await model.delete(request.activity) } }
            )
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
            VStack(spacing: 0) {
                WeekHeader(week: model.selectedWeek, termCalendar: model.termCalendar, makeupDays: model.makeupDays(inWeek: model.selectedWeek))
                pager
            }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if model.refreshError != nil {
                        GxuStaleBanner(updatedAt: model.updatedAt, message: model.refreshError?.userMessage)
                    }
                }
                .overlay(alignment: .bottom) { weekControls }
        }
    }

    /// 横向分页。不用 `TabView(.page)`：它的 UIKit 容器会让内部滚动视图重复计算顶部安全区。
    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(1...model.weekCount, id: \.self) { week in
                    WeekGridView(week: week, model: model) { detail = $0 }
                        .containerRelativeFrame(.horizontal)
                        .id(week)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: weekPosition)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var weekPosition: Binding<Int?> {
        Binding(
            get: { model.selectedWeek },
            set: { if let week = $0 { model.selectedWeek = week } }
        )
    }

    /// 浮动玻璃控件。“回到本周”只在离开本周时出现，并与两侧按钮一起变形。
    private var weekControls: some View {
        GlassGroup(spacing: GxuDesign.Spacing.m) {
            HStack(spacing: GxuDesign.Spacing.m) {
                GlassButton(systemImage: "chevron.left", accessibilityLabel: "上一周") { moveWeek(-1) }
                    .disabled(model.selectedWeek <= 1)
                    .gxuGlassID("previous", in: glassNamespace)
                if !model.isViewingCurrentWeek {
                    GlassButton("本周", systemImage: "arrow.uturn.backward", prominent: true) { select(model.currentWeek) }
                        .gxuGlassID("current", in: glassNamespace)
                }
                GlassButton(systemImage: "chevron.right", accessibilityLabel: "下一周") { moveWeek(1) }
                    .disabled(model.selectedWeek >= model.weekCount)
                    .gxuGlassID("next", in: glassNamespace)
            }
        }
        .padding(.bottom, GxuDesign.Spacing.m)
        .animation(.smooth, value: model.isViewingCurrentWeek)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if model.phase == .content {
                Menu {
                    Picker("跳转到", selection: $model.selectedWeek) {
                        ForEach(1...model.weekCount, id: \.self) { Text("第 \($0) 周").tag($0) }
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text("第 \(model.selectedWeek) 周").font(.headline)
                        Text(model.subtitle()).font(.caption2).foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                }
                .tint(.primary)
                .accessibilityLabel("第 \(model.selectedWeek) 周，\(model.subtitle())，选择周次")
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            if model.phase == .content {
                Menu {
                    Button("添加日程", systemImage: "plus") { addActivity() }
                    Button("我的日程", systemImage: "list.bullet") { showActivityList = true }
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("日程")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if model.phase == .content {
                if model.isRefreshing {
                    ProgressView()
                } else if model.availableTerms.count > 1 {
                    Menu {
                        Picker("学期", selection: termBinding) {
                            ForEach(model.availableTerms, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("切换学期")
                }
            }
        }
    }

    private var termBinding: Binding<AcademicTerm> {
        Binding(
            get: { model.term ?? model.availableTerms[0] },
            set: { term in Task { await model.select(term: term) } }
        )
    }

    #if DEBUG
    /// 截图自查：`-GxuScheduleSheet add|list|detail`
    private func debugPresentSheet() async {
        let args = ProcessInfo.processInfo.arguments
        guard model.phase == .content, let i = args.firstIndex(of: "-GxuScheduleSheet"), i + 1 < args.count else { return }
        switch args[i + 1] {
        case "add": addActivity()
        case "list":
            await model.save(CustomActivity(name: "社团例会", note: "活动室", weekday: 3, begin: 9, end: 10, weekFrom: 1, weekTo: 12, colorHex: 0xB3E5FC))
            await model.save(CustomActivity(name: "英语角", weekday: 5, begin: 11, end: 12, weekFrom: 3, weekTo: 3, colorHex: 0xFFE0B2))
            showActivityList = true
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

    private func moveWeek(_ delta: Int) { select(model.selectedWeek + delta) }

    private func select(_ week: Int) {
        withAnimation(.smooth) { model.selectedWeek = min(max(week, 1), model.weekCount) }
    }
}

/// 打开日程编辑 sheet 的请求
struct ActivityEditorRequest: Identifiable {
    let activity: CustomActivity
    let isNew: Bool
    var id: String { activity.id }
}
