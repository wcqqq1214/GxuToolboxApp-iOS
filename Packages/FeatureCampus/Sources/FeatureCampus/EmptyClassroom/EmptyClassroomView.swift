import GxuAuth
import GxuDesign
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
