import GxuAuth
import GxuDesign
import GxuFoundation
import ScheduleKit
import SwiftUI

struct EmptyClassroomView: View {
    @Environment(\.services) private var services
    @State private var model: EmptyClassroomModel
    @State private var cache = EmptyClassroomCacheController()
    #if DEBUG
    @State private var debugCache = false
    @State private var debugPicker = CommandLine.arguments.contains("-GxuEmptyScreen") && CommandLine.arguments.last == "picker"
    #endif

    init() { _model = State(initialValue: EmptyClassroomModel(context: CampusContext())) }

    var body: some View {
        Group {
            if !model.hasFinishedSetup {
                GxuLoadingView("正在加载…")
            } else if let error = model.setupError, model.term == nil {
                GxuErrorView(error) { Task { await model.start(services: services) } }
            } else {
                content
            }
        }
        .navigationTitle("空闲教室")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CacheManagerView(model: model, cache: cache)
                } label: { Image(systemName: "externaldrive.badge.icloud") }
                .accessibilityLabel("缓存管理")
            }
        }
        .task {
            await model.start(services: services)
            #if DEBUG
            if CommandLine.arguments.contains("-GxuEmptyScreen") {
                if CommandLine.arguments.last == "room" { model.mode = .room }
                if CommandLine.arguments.last == "cache" { debugCache = true }
            }
            #endif
        }
        #if DEBUG
        .navigationDestination(isPresented: $debugCache) { CacheManagerView(model: model, cache: cache) }
        .sheet(isPresented: $debugPicker) { RoomPickerSheet(model: model, selection: .single) }
        #endif
    }

    private var content: some View {
        VStack(spacing: 0) {
            Picker("查询方式", selection: $model.mode) {
                ForEach(EmptyClassroomModel.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, GxuDesign.Layout.pageMargin)
            .padding(.bottom, GxuDesign.Spacing.s)
            switch model.mode {
            case .time: TimeQueryView(model: model, cache: cache)
            case .room: RoomModeView(model: model, cache: cache)
            }
        }
    }
}

struct PeriodStrip: View {
    var freeRuns: [FreeRun]
    var highlight: ClosedRange<Int>?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...EmptyClassroomConstants.periods, id: \.self) { period in
                let free = freeRuns.contains { (($0.begin)...($0.end)).contains(period) }
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(free ? Color.green.opacity(0.75) : Color(.tertiarySystemFill))
                    .frame(height: 8)
                    .overlay {
                        if let highlight, highlight != 1...EmptyClassroomConstants.periods, highlight.contains(period) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

private func runText(_ runs: [FreeRun]) -> String {
    runs.map { $0.begin == $0.end ? "第\($0.begin)节" : "第\($0.begin)-\($0.end)节" }.joined(separator: "、")
}


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

@MainActor @ViewBuilder
private func termPicker(_ model: EmptyClassroomModel) -> some View {
    if model.context.terms.count > 1 {
        Picker("学期", selection: Binding(get: { model.term ?? model.context.terms[0] }, set: { term in Task { await model.select(term: term) } })) {
            ForEach(model.context.terms, id: \.self) { Text($0.displayName).tag($0) }
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
            content
        }
        .sheet(isPresented: $showPicker) { RoomPickerSheet(model: model, selection: .single) }
    }

    @ViewBuilder
    private var content: some View {
        if model.room == nil {
            Section { Text("选择一间教室，查看它这一周的空闲时段").foregroundStyle(.secondary) }
        } else if model.snapshot(week: model.roomWeek) == nil {
            Section {
                Text("这一周还没有缓存，无法显示空闲时段").foregroundStyle(.secondary)
                NavigationLink("去缓存管理") { CacheManagerView(model: model, cache: cache) }
            }
        } else {
            let snapshot = model.snapshot(week: model.roomWeek)
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
                if let snapshot, !snapshot.complete { Text("这一周只缓存了 \(snapshot.completedDays)/7 天，没缓存的日期不会显示空闲。") }
            }
            if let error = model.roomError { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
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

struct RoomPickerSheet: View {
    enum Selection { case single, multiple }
    @Bindable var model: EmptyClassroomModel
    let selection: Selection
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var found: [EmptyClassroomFloor.SearchSection] = []

    var body: some View {
        NavigationStack {
            Group {
                if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults
                } else if model.buildingSummaries.isEmpty {
                    GxuEmptyView("还没有教室数据", systemImage: "building.2", message: "缓存一周的空闲教室数据后，这里会列出教学楼和教室")
                } else {
                    List(model.buildingSummaries) { group in
                        NavigationLink { FloorListView(model: model, selection: selection, building: group, dismiss: { dismiss() }) } label: {
                            VStack(alignment: .leading) { Text(group.title); Text("\(group.roomCount) 间教室").font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "搜索教室名称或场地类别")
            .task(id: search) {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let repository = model.repository else { return }
                found = EmptyClassroomFloor.groupSearchResults((try? await repository.searchRooms(keyword: search)) ?? [])
            }
            .navigationTitle(selection == .single ? "选择教室" : "指定教室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(selection == .single ? "取消" : "清除") { if selection == .multiple { model.selectedRooms = []; Task { await model.runQuery(reset: true) } }; dismiss() } }
                if selection == .multiple {
                    ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss(); Task { await model.runQuery(reset: true) } } }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var searchResults: some View {
        List {
            if found.isEmpty { Text("没有找到匹配的教室").foregroundStyle(.secondary) }
            ForEach(found) { section in
                Section(section.title) { ForEach(section.rooms) { room in RoomPickRow(model: model, selection: selection, room: room, dismiss: { dismiss() }) } }
            }
        }
    }
}

private struct FloorListView: View {
    @Bindable var model: EmptyClassroomModel
    let selection: RoomPickerSheet.Selection
    let building: EmptyClassroomFloor.BuildingGroup
    let dismiss: () -> Void
    @State private var floors: [EmptyClassroomFloor.FloorGroup] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if !loaded { GxuLoadingView("正在加载…") } else {
                List(floors) { floor in
                    NavigationLink {
                        List(floor.rooms) { RoomPickRow(model: model, selection: selection, room: $0, dismiss: dismiss) }
                            .navigationTitle("\(building.title) · \(floor.title)")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        LabeledContent(floor.title) { Text("\(floor.rooms.count) 间").foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .navigationTitle(building.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let repository = model.repository else { return }
            floors = EmptyClassroomFloor.groupRoomsByFloor((try? await repository.listRooms(inBuilding: building.building)) ?? [])
            loaded = true
        }
    }
}

private struct RoomPickRow: View {
    @Bindable var model: EmptyClassroomModel
    let selection: RoomPickerSheet.Selection
    let room: RoomRecord
    let dismiss: () -> Void

    var body: some View {
        Button {
            switch selection {
            case .single:
                Task { await model.select(room: room) }
                dismiss()
            case .multiple:
                if let i = model.selectedRooms.firstIndex(of: room) { model.selectedRooms.remove(at: i) } else { model.selectedRooms.append(room) }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name).foregroundStyle(Color.primary)
                    let detail = room.placeType
                    if !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(Color.secondary) }
                }
                Spacer()
                if (selection == .single && model.room?.id == room.id) || (selection == .multiple && model.selectedRooms.contains(room)) {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
    }
}
