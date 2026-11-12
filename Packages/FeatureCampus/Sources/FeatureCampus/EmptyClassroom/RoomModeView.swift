import ScheduleKit
import SwiftUI

struct RoomModeView: View {
    @Bindable var model: EmptyClassroomModel
    let cache: EmptyClassroomCacheController
    @State private var showPicker = false

    var body: some View {
        List {
            Section {
                termPicker(model)
                Button { showPicker = true } label: {
                    LabeledContent("教室") {
                        Text(model.room.map { [$0.building, $0.name].filter { !$0.isEmpty }.joined(separator: " ") } ?? "选择教室").foregroundStyle(model.room == nil ? .secondary : .primary)
                    }
                }
                .buttonStyle(.plain)
                Picker("周次", selection: Binding(get: { model.roomWeek }, set: { week in
                    model.roomWeek = week
                    Task { await model.loadRoomRuns() }
                })) {
                    ForEach(1...EmptyClassroomConstants.maxWeeks, id: \.self) { week in
                        Text("第 \(week) 周" + (model.cachedWeeks.contains(week) ? "" : "（未缓存）")).tag(week)
                    }
                }
            }
            if model.room != nil { content }
        }
        .sheet(isPresented: $showPicker) { RoomPickerSheet(model: model, selection: .single) }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = model.snapshot(week: model.roomWeek) {
            Section {
                ForEach(1...EmptyClassroomConstants.days, id: \.self) { day in
                    let runs = model.roomRuns.filter { $0.day == day }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text([WeekdayName.full(day), model.dateLabel(week: model.roomWeek, day: day)].compactMap { $0 }.joined(separator: " ")).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(runs.isEmpty ? "全天无空闲" : runText(runs)).font(.caption).foregroundStyle(.secondary)
                        }
                        PeriodStrip(freeRuns: runs, highlight: nil)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("空闲时段")
            } footer: {
                if !snapshot.complete { Text("这一周只缓存了 \(snapshot.completedDays)/7 天，没缓存的日期不会显示空闲。") }
            }
            if let error = model.roomError { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        } else {
            Section {
                Text("这一周还没有缓存，无法显示空闲时段").foregroundStyle(.secondary)
                NavigationLink("去缓存管理") { CacheManagerView(model: model, cache: cache) }
            }
        }
    }
}
