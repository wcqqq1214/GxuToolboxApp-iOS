import SwiftUI

/// Phase 0 占位：空的三标签。Shell 目录从此归 Agent B 所有。
struct RootView: View {
    var body: some View {
        TabView {
            Tab("课表", systemImage: "calendar") { Text("课表") }
            Tab("工具箱", systemImage: "square.grid.2x2") { Text("工具箱") }
            Tab("设置", systemImage: "gearshape") { Text("设置") }
        }
    }
}

#Preview { RootView() }
