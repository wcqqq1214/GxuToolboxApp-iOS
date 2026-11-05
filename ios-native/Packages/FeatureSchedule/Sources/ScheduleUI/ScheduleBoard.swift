import GxuDesign
import GxuFoundation
import ScheduleKit
import SwiftUI

/// 周课表主体：星期表头 + 横向分页的周网格 + 底部浮动的周切换玻璃控件。个人课表和班级课表共用。
struct ScheduleBoard: View {
    let model: ScheduleViewModel
    let onSelect: (ConflictGroup) -> Void
    @Environment(\.gxuAccessoryHeight) private var accessoryHeight

    var body: some View {
        VStack(spacing: 0) {
            WeekHeader(week: model.selectedWeek, termCalendar: model.termCalendar, makeupDays: model.makeupDays(inWeek: model.selectedWeek))
            pager
        }
        .overlay(alignment: .bottom) { returnToCurrent }
        .animation(.smooth, value: model.isViewingCurrentWeek)
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

    /// 滑动切周；不在本周时只在底部放一个小的“回到本周”玻璃按钮
    @ViewBuilder
    private var returnToCurrent: some View {
        if !model.isViewingCurrentWeek {
            GlassGroup {
                GlassButton("回到本周", systemImage: "arrow.uturn.backward") {
                    withAnimation(.smooth) { model.selectedWeek = min(max(model.currentWeek, 1), model.weekCount) }
                }
            }
            .padding(.bottom, GxuDesign.Spacing.m + accessoryHeight)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

/// 导航栏中间的“第 N 周 + 日期范围”。标题本身就是菜单：选周次，有多个学期时还能选学期。
struct ScheduleWeekTitle: View {
    @Bindable var model: ScheduleViewModel
    /// 学期菜单。只读课表（班级课表）不传
    var terms: [AcademicTerm] = []
    var term: Binding<AcademicTerm>?

    var body: some View {
        Menu {
            Picker("跳转到", selection: $model.selectedWeek) {
                ForEach(1...model.weekCount, id: \.self) { Text("第 \($0) 周").tag($0) }
            }
            if let term, terms.count > 1 {
                Picker("学期", selection: term) {
                    ForEach(terms, id: \.self) { Text($0.displayName).tag($0) }
                }
            }
        } label: {
            // 标题和日期范围在同一条中轴线上：箭头做成 overlay，不占布局宽度，不会把文字挤偏
            VStack(spacing: 0) {
                Text("第 \(model.selectedWeek) 周")
                    .font(.headline)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.selectedWeek)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .offset(x: 16)
                    }
                Text(model.subtitle()).font(.caption2).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
        }
        .tint(.primary)
        .accessibilityLabel("第 \(model.selectedWeek) 周，\(model.subtitle())，选择周次\(term == nil ? "" : "或学期")")
    }
}
