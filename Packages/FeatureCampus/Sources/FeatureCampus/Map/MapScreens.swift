import GxuDesign
import ScheduleKit
import SwiftUI

struct MapNavigationView: View {
    @Environment(\.openURL) private var openURL
    @State private var flow = MapOpenFlow()
    @State private var type = ""
    @State private var query = ""

    private var places: [CampusPlace] {
        CampusPlaces.all.filter { (type.isEmpty || $0.type == type) && $0.matches(query: query) }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GxuDesign.Spacing.s) {
                        chip("全部", value: "")
                        ForEach(CampusPlaces.types, id: \.self) { chip($0, value: $0) }
                    }
                }
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(places) { place in
                    Button {
                        flow.open(text: place.fullName, openURL: openURL)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name).foregroundStyle(Color.primary)
                                let sub = ([place.type] + place.aliases.prefix(3)).joined(separator: " · ")
                                Text(sub).font(.footnote).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.triangle.turn.up.right.circle").foregroundStyle(.tint)
                        }
                    }
                    .accessibilityHint("在地图中打开")
                }
            } footer: {
                if places.isEmpty { Text("没有符合条件的地点") } else { Text("点击后在“地图”中搜索这个地点。") }
            }
        }
        .searchable(text: $query, prompt: "搜索地点")
        .navigationTitle("地图导航")
        .navigationBarTitleDisplayMode(.inline)
        .gxuToast($flow.toast)
        .confirmationDialog(
            "请选择打开方式", isPresented: Binding(get: { flow.pending != nil }, set: { if !$0 { flow.pending = nil } }),
            titleVisibility: .visible, presenting: flow.pending
        ) { pending in
            ForEach(pending.apps, id: \.self) { app in
                Button(app.label) { flow.launch(app, keyword: pending.keyword, openURL: openURL) }
            }
        }
    }

    private func chip(_ title: String, value: String) -> some View {
        let selected = type == value
        return Button { withAnimation(.snappy) { type = value } } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, GxuDesign.Spacing.m)
                .padding(.vertical, GxuDesign.Spacing.s)
                .background(selected ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct TeachBuildingListView: View {
    #if DEBUG
    @State private var debugFloor = CommandLine.arguments.contains("-GxuFloorDemo")
    #endif

    var body: some View {
        List(TeachBuildings.all) { building in
            NavigationLink {
                FloorListView(building: building)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(building.name)
                    Text("\(building.floors.count) 张楼层图").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("教学楼平面图")
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG
        .navigationDestination(isPresented: $debugFloor) {
            if let building = TeachBuildings.all.first, let floor = building.floors.first { FloorMapView(building: building, floor: floor) }
        }
        #endif
    }
}

private struct FloorListView: View {
    let building: TeachBuilding

    var body: some View {
        List(building.floors) { floor in
            NavigationLink(floor.name) { FloorMapView(building: building, floor: floor) }
        }
        .navigationTitle(building.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FloorMapView: View {
    let building: TeachBuilding
    let floor: TeachBuilding.Floor
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: TeachBuildings.imageURL(floor)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(zoomAndPan)
                        .onTapGesture(count: 2) { withAnimation(.smooth) { toggleZoom() } }
                        .accessibilityLabel("\(building.name)\(floor.name)")
                        .accessibilityHint("双击放大或还原，双指缩放")
                case .failure:
                    GxuErrorView("楼层图加载失败，请检查网络后重试")
                default:
                    GxuLoadingView("正在加载楼层图…")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .navigationTitle(floor.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var zoomAndPan: some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .onChanged { scale = min(max(committedScale * $0.magnification, 1), 6) }
                .onEnded { _ in
                    committedScale = scale
                    if scale <= 1 { withAnimation(.smooth) { offset = .zero; committedOffset = .zero } }
                },
            DragGesture()
                .onChanged { if scale > 1 { offset = CGSize(width: committedOffset.width + $0.translation.width, height: committedOffset.height + $0.translation.height) } }
                .onEnded { _ in committedOffset = offset }
        )
    }

    private func toggleZoom() {
        if scale > 1 {
            scale = 1; committedScale = 1; offset = .zero; committedOffset = .zero
        } else {
            scale = 2.5; committedScale = 2.5
        }
    }
}
