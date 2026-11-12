import GxuDesign
import ScheduleKit
import SwiftUI

struct TimeQueryView: View {
    @Bindable var model: EmptyClassroomModel
    let cache: EmptyClassroomCacheController
    @State private var showBuildings = false
    @State private var showRooms = false

    var body: some View {
        if model.cachedWeeks.isEmpty {
            NoCacheView(model: model, cache: cache)
        } else {
            List {
                criteria
                filters
                resultSections
            }
            .searchable(text: $model.keyword, prompt: "搜索教室名称或场地类别")
            .task(id: model.keyword) {
                try? await Task.sleep(for: .milliseconds(300))
                if !Task.isCancelled { await model.runQuery(reset: true) }
            }
            .sheet(isPresented: $showBuildings) { BuildingFilterSheet(model: model) }
            .sheet(isPresented: $showRooms) { RoomPickerSheet(model: model, selection: .multiple) }
        }
    }

    private var criteria: some View {
        Section("时间") {
            termPicker(model)
            HStack {
                Picker("周次", selection: Binding(get: { model.queryWeek ?? model.cachedWeeks[0] }, set: { week in
                    model.queryWeek = week
                    Task { await model.reloadCachedDays(); await model.runQuery(reset: true) }
                })) {
                    ForEach(model.cachedWeeks, id: \.self) { Text("第 \($0) 周").tag($0) }
                }
                Spacer()
                if model.cachedDays.isEmpty {
                    Text("这周还没缓存完整的日期").font(.footnote).foregroundStyle(.secondary)
                } else {
                    Picker("日期", selection: Binding(get: { model.queryDay ?? model.cachedDays[0] }, set: { day in
                        model.queryDay = day
                        Task { await model.runQuery(reset: true) }
                    })) {
                        ForEach(model.cachedDays, id: \.self) { day in
                            Text([WeekdayName.full(day), model.queryWeek.flatMap { model.dateLabel(week: $0, day: day) }].compactMap { $0 }.joined(separator: " ")).tag(day)
                        }
                    }
                    .labelsHidden()
                }
            }
            HStack {
                Text("节次")
                Spacer()
                Picker("开始", selection: Binding(get: { model.startPeriod }, set: { value in
                    model.startPeriod = value
                    model.endPeriod = max(model.endPeriod, value)
                    Task { await model.runQuery(reset: true) }
                })) {
                    ForEach(ClassPeriods.all, id: \.number) { Text("第 \($0.number) 节").tag($0.number) }
                }
                .labelsHidden()
                Text("至").foregroundStyle(.secondary)
                Picker("结束", selection: Binding(get: { max(model.endPeriod, model.startPeriod) }, set: { value in
                    model.endPeriod = value
                    Task { await model.runQuery(reset: true) }
                })) {
                    ForEach(ClassPeriods.all.filter { $0.number >= model.startPeriod }, id: \.number) { Text("第 \($0.number) 节").tag($0.number) }
                }
                .labelsHidden()
            }
            if let first = ClassPeriods.period(model.startPeriod), let last = ClassPeriods.period(max(model.endPeriod, model.startPeriod)) {
                Text("\(first.startText)–\(last.endText)").font(.footnote).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    private var filters: some View {
        Section("筛选") {
            Button { showBuildings = true } label: {
                LabeledContent("楼栋") { Text(model.selectedBuildings.isEmpty ? "全部" : "已选 \(model.selectedBuildings.count) 栋").foregroundStyle(.secondary) }
            }
            Button { showRooms = true } label: {
                LabeledContent("指定教室") { Text(model.selectedRooms.isEmpty ? "不限" : "已选 \(model.selectedRooms.count) 间").foregroundStyle(.secondary) }
            }
            HStack {
                Picker("排序", selection: Binding(get: { model.sortMode }, set: { mode in
                    model.sortMode = mode
                    Task { await model.runQuery(reset: true) }
                })) {
                    Text("默认").tag(TimeQuerySortMode.default)
                    Text("空闲时间").tag(TimeQuerySortMode.free)
                }
                .pickerStyle(.segmented)
                if model.sortMode == .free {
                    Button {
                        model.toggleSortDirection()
                        Task { await model.runQuery(reset: true) }
                    } label: {
                        Image(systemName: model.sortDirection == .desc ? "arrow.down" : "arrow.up")
                    }
                    .accessibilityLabel(model.sortDirection == .desc ? "空闲最多优先" : "空闲最少优先")
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var resultSections: some View {
        if model.queryDay == nil {
            Section {
                Text("这一周还没有可查询的日期")
                NavigationLink("去缓存管理") { CacheManagerView(model: model, cache: cache) }
            }
        } else if let error = model.queryError {
            Section {
                Label("查询失败：\(error)", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                if model.isQuerying {
                    ProgressView("正在重新查询…")
                } else {
                    Button("重试") { Task { await model.runQuery(reset: true) } }
                }
            }
        } else if model.results.isEmpty, !model.isQuerying {
            Section {
                Text("这个时间段没有符合条件的空闲教室")
                if model.hasRoomFilters {
                    Button("清除楼栋和教室筛选") { Task { await model.clearRoomFilters() } }
                }
            } footer: {
                if !model.keyword.isEmpty {
                    Text("可以缩短或清除搜索关键词。")
                } else if !model.hasRoomFilters {
                    Text("可以换个日期或缩短节次范围。")
                }
            }
        } else {
            let range = min(model.startPeriod, model.endPeriod)...max(model.startPeriod, model.endPeriod)
            ForEach(EmptyClassroomLogic.group(model.results), id: \.title) { group in
                Section(group.title) {
                    ForEach(group.items) { result in
                        RoomResultRow(result: result, range: range)
                            .onAppear { if result.id == model.results.last?.id { Task { await model.loadMore() } } }
                    }
                }
            }
            Section {
                if model.isQuerying { HStack { ProgressView(); Text("正在加载…").foregroundStyle(.secondary) } }
            } footer: {
                if !model.isQuerying { Text("共 \(model.totalCount) 间空闲教室") }
            }
        }
    }
}

private struct RoomResultRow: View {
    let result: RoomAvailabilityResult
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.room.name).font(.body.weight(.medium))
                Spacer()
                Text("空闲 \(result.freePeriodCount) 节").font(.footnote.weight(.semibold)).foregroundStyle(.green)
            }
            let detail = result.room.placeType
            if !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(.secondary) }
            PeriodStrip(freeRuns: result.freeRuns, highlight: range)
            Text(runText(result.freeRuns)).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct NoCacheView: View {
    @Bindable var model: EmptyClassroomModel
    let cache: EmptyClassroomCacheController

    var body: some View {
        VStack(spacing: GxuDesign.Spacing.l) {
            GxuEmptyView(
                "还没有缓存", systemImage: "externaldrive.badge.icloud",
                message: "空闲教室需要先把某一周的数据缓存到本机，之后可以离线查询。"
            )
            NavigationLink("去缓存管理") { CacheManagerView(model: model, cache: cache) }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, GxuDesign.Spacing.xl)
        }
    }
}

private struct BuildingFilterSheet: View {
    @Bindable var model: EmptyClassroomModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.buildingSummaries) { group in
                Button {
                    if let i = model.selectedBuildings.firstIndex(of: group.building) { model.selectedBuildings.remove(at: i) } else { model.selectedBuildings.append(group.building) }
                } label: {
                    HStack {
                        VStack(alignment: .leading) { Text(group.title).foregroundStyle(Color.primary); Text("\(group.roomCount) 间教室").font(.footnote).foregroundStyle(Color.secondary) }
                        Spacer()
                        if model.selectedBuildings.contains(group.building) { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
            }
            .navigationTitle("选择楼栋")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("清除") { model.selectedBuildings = [] } }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss(); Task { await model.runQuery(reset: true) } } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
