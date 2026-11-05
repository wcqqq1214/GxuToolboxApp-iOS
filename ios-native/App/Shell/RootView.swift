import FeatureAccount
import GxuAuth
import GxuDesign
import ScheduleUI
import SwiftUI

enum AppTab: Hashable {
    case schedule, toolbox, settings
}

/// 三个标签：课表 / 工具箱 / 设置。系统 TabView 在 iOS 26 自动是玻璃，**不要**给它设背景。
struct RootView: View {
    @State private var theme = GxuTheme()
    @State private var selection: AppTab = Self.initialTab
    @Environment(\.services) private var services

    /// DEBUG：`-GxuTab toolbox|settings` 直接打开对应标签（截图自查用）
    private static var initialTab: AppTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-GxuTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "toolbox": return .toolbox
            case "settings": return .settings
            default: break
            }
        }
        #endif
        return .schedule
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("课表", systemImage: "calendar", value: AppTab.schedule) {
                ScheduleFeature.makeRootView(onRequestLogin: { selection = .settings })
            }
            Tab("工具箱", systemImage: "square.grid.2x2", value: AppTab.toolbox) {
                ToolboxView()
            }
            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                SettingsHomeView()
            }
        }
        .gxuTabBarMinimizeOnScroll()
        .gxuTheme(theme)
        #if DEBUG
        .environment(\.services, DemoMode.isEnabled ? DemoMode.services : services)
        #endif
    }
}

#Preview { RootView() }
