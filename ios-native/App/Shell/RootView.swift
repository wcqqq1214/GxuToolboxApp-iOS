import ExamKit
import FeatureAccount
import FeatureCampus
import GxuAuth
import GxuFoundation
import GxuDesign
import GxuStorage
import ScheduleKit
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
    /// 每分钟更新一次，让“有没有下一件事”随时间变化（附件栏据此显示 / 隐藏）
    @State private var clock = Date.now
    /// 工具箱里有二级页面时，底部附件要关掉（它不会跟着标签栏一起隐藏）
    @State private var toolboxPushed = false
    @State private var preferences = SchedulePreferencesStore(shared: RootView.makeSharedStore())
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
                HomeView(model: home, onRequestLogin: { selection = .settings }).gxuAccessoryInset()
            }
            Tab("课表", systemImage: "calendar", value: AppTab.schedule) {
                ScheduleFeature.makeRootView(onRequestLogin: { selection = .settings }, layers: layersProvider).gxuAccessoryInset()
            }
            Tab("工具箱", systemImage: "square.grid.2x2", value: AppTab.toolbox) {
                ToolboxView(onSelectTab: { selection = $0 }, isPushed: $toolboxPushed).gxuAccessoryInset()
            }
            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                SettingsHomeView().gxuAccessoryInset()
            }
        }
        .gxuTabBarMinimizeOnScroll()
        // 附件只在“课表”和“工具箱”首页出现：“今天”本身就是下一件事，设置页的列表不该被盖住；没有下一件事时直接隐藏；
        // 工具箱的二级页面隐藏标签栏时附件也一起收起
        .gxuTabAccessory(isEnabled: home.phase == .ready && (selection == .schedule || (selection == .toolbox && !toolboxPushed)) && home.hasNextEvent(now: clock)) { NextEventAccessory(model: home) }
        .gxuTheme(theme)
        .environment(preferences)
        .environment(\.scheduleMapURL, Self.mapURL)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                clock = .now
            }
        }
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
    /// 课程详情“导航”：体育学院场馆直接搜关键词，其余按教室文案解析教学楼（解析不到就不显示按钮）
    static let mapURL: ScheduleMapURLProvider = { target in
        if let keyword = target.mapKeyword {
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [URLQueryItem(name: "q", value: keyword)]
            return components?.url
        }
        return CampusPlaces.place(forRoom: target.room)?.mapsURL
    }

    /// 课表上的额外图层：考试（读 ExamKit 本地缓存里这个学期的考试）和实验课对教师 / 地点的覆盖（读 PEC 本地缓存）。
    /// 都只读本地缓存、不联网；联网刷新由首页 / 各自的页面负责。
    private var layersProvider: ScheduleExtraLayersProvider {
        let services = resolvedServices
        return { studentId, term in
            let items = (try? await ExamRepository(database: services.database).allExams(studentId: studentId)) ?? []
            let exams = items.compactMap { item -> GridExam? in
                guard let start = item.date, let end = Self.examEnd(item.exam.time, start: start) else { return nil }
                return GridExam(id: item.id, title: item.exam.course, location: item.exam.classroom, seat: item.exam.seatText, start: start, end: end)
            }
            let overrides = await PhyExpOverrides.cached(database: services.database, studentId: studentId)
            return ScheduleExtraLayers(exams: exams, overrides: overrides)
        }
    }

    /// 考试时间串 “2026-01-23(09:00-11:00)” 里的结束时刻
    private static func examEnd(_ time: String, start: Date) -> Date? {
        guard let match = time.firstMatch(of: /\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)/), let h = Int(match.3), let m = Int(match.4) else { return nil }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: start)
    }

    /// 偏好存在 App Group 的 KV 里（小组件也能读）；演示模式用标准 UserDefaults，避免污染真实数据
    static func makeSharedStore() -> any SharedStore {
        #if DEBUG
        if DemoMode.isEnabled { return UserDefaultsSharedStore(suiteName: nil) }
        #endif
        return UserDefaultsSharedStore()
    }

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

