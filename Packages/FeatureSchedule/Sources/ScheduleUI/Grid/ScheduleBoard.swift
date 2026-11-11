import GxuDesign
import GxuFoundation
import ScheduleKit
import SwiftUI

struct ScheduleBoard: View {
    let model: ScheduleViewModel
    let onSelect: (ConflictGroup) -> Void
    var onSelectExam: (GridExam) -> Void = { _ in }
    @Environment(\.gxuAccessoryHeight) private var accessoryHeight

    var body: some View {
        VStack(spacing: 0) {
            WeekHeader(week: model.selectedWeek, termCalendar: model.termCalendar, makeupDays: model.makeupDays(inWeek: model.selectedWeek))
            pager
        }
        .overlay(alignment: .bottom) { returnToCurrent }
        .animation(.smooth, value: model.isViewingCurrentWeek)
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(1...model.weekCount, id: \.self) { week in
                    WeekGridView(week: week, model: model, onSelect: onSelect, onSelectExam: onSelectExam)
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

struct ScheduleWeekTitle: View {
    @Bindable var model: ScheduleViewModel
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
