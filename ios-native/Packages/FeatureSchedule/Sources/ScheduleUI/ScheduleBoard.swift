import GxuDesign
import ScheduleKit
import SwiftUI

/// 周课表主体：星期表头 + 横向分页的周网格 + 底部浮动的周切换玻璃控件。个人课表和班级课表共用。
struct ScheduleBoard: View {
    let model: ScheduleViewModel
    let onSelect: (ConflictGroup) -> Void
    @Namespace private var glassNamespace
    @Environment(\.gxuAccessoryHeight) private var accessoryHeight

    var body: some View {
        VStack(spacing: 0) {
            WeekHeader(week: model.selectedWeek, termCalendar: model.termCalendar, makeupDays: model.makeupDays(inWeek: model.selectedWeek))
            pager
        }
        .overlay(alignment: .bottom) { weekControls }
    }

    /// 横向分页。不用 `TabView(.page)`：它的 UIKit 容器会让内部滚动视图重复计算顶部安全区。
    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(1...model.weekCount, id: \.self) { week in
                    WeekGridView(week: week, model: model, onSelect: onSelect)
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
                GlassButton(systemImage: "chevron.left", accessibilityLabel: "上一周") { move(-1) }
                    .disabled(model.selectedWeek <= 1)
                    .gxuGlassID("previous", in: glassNamespace)
                if !model.isViewingCurrentWeek {
                    GlassButton("本周", systemImage: "arrow.uturn.backward", prominent: true) { select(model.currentWeek) }
                        .gxuGlassID("current", in: glassNamespace)
                }
                GlassButton(systemImage: "chevron.right", accessibilityLabel: "下一周") { move(1) }
                    .disabled(model.selectedWeek >= model.weekCount)
                    .gxuGlassID("next", in: glassNamespace)
            }
        }
        .padding(.bottom, GxuDesign.Spacing.m + accessoryHeight)
        .animation(.smooth, value: model.isViewingCurrentWeek)
    }

    private func move(_ delta: Int) { select(model.selectedWeek + delta) }

    private func select(_ week: Int) {
        withAnimation(.smooth) { model.selectedWeek = min(max(week, 1), model.weekCount) }
    }
}

/// 导航栏中间的“第 N 周 + 日期范围”，点开可跳转到任意一周
struct ScheduleWeekTitle: View {
    @Bindable var model: ScheduleViewModel

    var body: some View {
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
