import GxuAuth
import GxuDesign
import ScheduleKit
import SwiftUI

/// 分享课表图片的内容：周次选择 + 图片预览 + 分享按钮（工具栏）。弹窗和“导出课表”页面共用。
struct ShareScheduleContent: View {
    let model: ScheduleViewModel
    @Binding var week: Int
    let preferences: SchedulePreferencesStore
    var showsWeekPicker = true
    @Environment(\.colorScheme) private var colorScheme
    @State private var rendered: Image?

    var body: some View {
        ScrollView {
            VStack(spacing: GxuDesign.Spacing.l) {
                if showsWeekPicker {
                    Picker("周次", selection: $week) {
                        ForEach(1...model.weekCount, id: \.self) { Text("第 \($0) 周").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, GxuDesign.Layout.cardInset)
                }
                if let rendered {
                    rendered
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: GxuDesign.Radius.card, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                        .accessibilityLabel("第 \(week) 周课表预览")
                } else {
                    GxuLoadingView("正在生成图片…").frame(height: 300)
                }
            }
            .padding(.horizontal, GxuDesign.Layout.pageMargin)
            .padding(.vertical, GxuDesign.Spacing.l)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let rendered {
                    ShareLink(item: rendered, preview: SharePreview("第 \(week) 周课表", image: rendered)) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task(id: week) { render() }
    }

    @MainActor
    private func render() {
        let content = ShareableWeek(week: week, model: model)
            .environment(preferences)
            .environment(\.colorScheme, colorScheme)
            .frame(width: ShareableWeek.width)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        if let image = renderer.uiImage { rendered = Image(uiImage: image) }
    }
}

/// 分享本周课表（弹窗）
struct ShareScheduleSheet: View {
    let model: ScheduleViewModel
    @State var week: Int
    let preferences: SchedulePreferencesStore
    @Environment(\.dismiss) private var dismiss

    init(model: ScheduleViewModel, week: Int, preferences: SchedulePreferencesStore) {
        self.model = model
        self._week = State(initialValue: week)
        self.preferences = preferences
    }

    var body: some View {
        NavigationStack {
            ShareScheduleContent(model: model, week: $week, preferences: preferences, showsWeekPicker: false)
                .navigationTitle("分享课表")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}

/// 工具箱 →「导出课表」：独立页面，选周次后导出图片
struct ExportScheduleView: View {
    @Environment(\.services) private var services
    @Environment(SchedulePreferencesStore.self) private var preferences
    @State private var model = ScheduleViewModel()
    @State private var week = 1

    var body: some View {
        Group {
            switch model.phase {
            case .needsLogin:
                GxuEmptyView("还没有登录教务系统", systemImage: "person.crop.circle.badge.questionmark", message: "登录后即可导出你的课表")
            case .loading:
                GxuLoadingView("正在加载课表…")
            case .failed(let message):
                GxuErrorView(message) { Task { await model.load(services: services) } }
            case .content:
                ShareScheduleContent(model: model, week: $week, preferences: preferences)
            }
        }
        .navigationTitle("导出课表")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            model.palette = preferences.value.palette
            await model.load(services: services)
            week = model.selectedWeek
        }
    }
}

/// 导出的图：标题、星期表头、整天网格。固定宽度、不滚动，背景不透明。
struct ShareableWeek: View {
    static let width: CGFloat = 390
    let week: Int
    let model: ScheduleViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("第 \(week) 周").font(.title3.weight(.bold))
                Text(model.weekRangeText(week)).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, GxuDesign.Spacing.m)

            WeekHeader(week: week, termCalendar: model.termCalendar, makeupDays: model.makeupDays(inWeek: week))
            WeekBody(week: week, model: model, onSelect: { _ in })

            Text("西大工具箱")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.vertical, GxuDesign.Spacing.s)
        }
        .background(Color(.systemBackground))
        .dynamicTypeSize(.large)
    }
}
