import GxuDesign
import SwiftUI

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
