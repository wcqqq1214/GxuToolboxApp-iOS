import GxuDesign
import ScheduleKit
import SwiftUI

/// 分享本周课表：把当周课表渲染成一张图（`ImageRenderer`），用系统分享面板发出去。
struct ShareScheduleSheet: View {
    let model: ScheduleViewModel
    let week: Int
    let preferences: SchedulePreferencesStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let rendered {
                    rendered
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: GxuDesign.Radius.card, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                        .padding(GxuDesign.Spacing.l)
                        .accessibilityLabel("第 \(week) 周课表预览")
                } else {
                    GxuLoadingView("正在生成图片…").frame(height: 300)
                }
            }
            .navigationTitle("分享课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if let rendered {
                        ShareLink(item: rendered, preview: SharePreview("第 \(week) 周课表", image: rendered)) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task { render() }
        }
        .presentationDetents([.large])
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
