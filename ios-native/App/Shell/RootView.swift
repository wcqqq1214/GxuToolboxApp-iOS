import FeatureAccount
import GxuAuth
import GxuDesign
import ScheduleUI
import SwiftUI

enum AppTab: Hashable {
    case home, schedule, toolbox, settings
}

/// 三个标签：课表 / 工具箱 / 设置。系统 TabView 在 iOS 26 自动是玻璃，**不要**给它设背景。
struct RootView: View {
    @State private var theme = GxuTheme()
    @State private var selection: AppTab = Self.initialTab
    @State private var home = HomeModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.services) private var services

    /// DEBUG：`-GxuTab toolbox|settings` 直接打开对应标签（截图自查用）
    private static var initialTab: AppTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-GxuTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "toolbox": return .toolbox
            case "settings": return .settings
            case "schedule": return .schedule
            default: break
            }
        }
        #endif
        return .home
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("今天", systemImage: "sun.horizon", value: AppTab.home) {
                HomeView(model: home, onRequestLogin: { selection = .settings })
            }
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
        .gxuTabAccessory(isEnabled: home.phase == .ready) { NextEventAccessory(model: home) }
        .gxuTheme(theme)
        .task(id: AccountKey(studentId: services.accounts.studentId, state: services.accounts.states[.jw])) {
            await home.load(services: resolvedServices)
        }
        // 切标签 / 回前台时重读本地缓存（课表页刷新或改了冲突选择后，首页立刻同步）；回前台还会按需联网刷新
        .onChange(of: selection) { _, _ in Task { await home.reload(services: resolvedServices) } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await home.load(services: resolvedServices) } }
        }
        #if DEBUG
        .environment(\.services, DemoMode.isEnabled ? DemoMode.services : services)
        #endif
    }
}

extension RootView {
    private struct AccountKey: Hashable {
        var studentId: String?
        var state: AuthState?
    }

    /// DEBUG 的演示模式用内置假数据，其余情况用环境里的服务
    private var resolvedServices: AppServices {
        #if DEBUG
        DemoMode.isEnabled ? DemoMode.services : services
        #else
        services
        #endif
    }
}

#Preview { RootView() }
