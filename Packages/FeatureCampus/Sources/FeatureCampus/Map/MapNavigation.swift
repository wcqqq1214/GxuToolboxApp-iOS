import Foundation
import ScheduleKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 地图导航的平台部分（RN `openMap.ts` + `useMapNavigation.ts`）：检测已安装的地图应用、按 RN 的规则决定怎么打开。
/// 纯逻辑（链接、决定）在 ScheduleKit 的 `MapApp` / `MapOpenPlan`，楼名解析在 `CampusPlaces.parse`。
public enum MapNavigation {
    /// 显示顺序：Apple 地图（系统自带，始终可用）、高德、百度。
    /// 高德 / 百度要靠 `canOpenURL` 探测，需要在 Info.plist 的 `LSApplicationQueriesSchemes` 里声明 `iosamap`、`baidumap`，没声明时探测一律为否，只会剩 Apple 地图。
    @MainActor
    public static func installedApps() -> [MapApp] {
        #if DEBUG
        if CommandLine.arguments.contains("-GxuMapAllApps") { return MapApp.allCases }   // 截图自查：假装三个地图都装了
        #endif
        #if canImport(UIKit)
        return MapApp.allCases.filter { app in
            if app == .apple { return true }
            guard let url = app.url(keyword: MapApp.probeKeyword) else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
        #else
        return [.apple]
        #endif
    }

    /// RN `openMap(text, keyword?)` 的决定。`text` 交给楼名解析；`keyword` 是调用方直接指定的搜索词。
    @MainActor
    public static func plan(text: String, keyword: String? = nil, installed: [MapApp]? = nil) -> MapOpenPlan {
        let direct = keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // 直接指定了关键词就不必解析（RN：`keyword?.trim() || parseBuilding(text)?.fullName`）
        let parsed = direct.isEmpty ? CampusPlaces.parse(text)?.fullName : nil
        return MapOpenPlan.make(keyword: direct, parsedFullName: parsed, installed: installed ?? installedApps())
    }
}

/// “选一个地图应用 / 打开失败 / 解析不到”的界面流程（地图导航列表用；课程详情在 ScheduleUI 里有同样的流程）。
@MainActor @Observable
final class MapOpenFlow {
    struct Pending: Identifiable { let keyword: String; let apps: [MapApp]; var id: String { keyword } }
    var pending: Pending?
    var toast: String?

    func open(text: String, keyword: String? = nil, openURL: OpenURLAction) {
        switch MapNavigation.plan(text: text, keyword: keyword) {
        case .unparsed: toast = MapOpenPlan.unparsedMessage
        case .noApp: toast = MapOpenPlan.noAppMessage
        case .open(let keyword, let apps):
            if apps.count == 1, let app = apps.first { launch(app, keyword: keyword, openURL: openURL) } else { pending = Pending(keyword: keyword, apps: apps) }
        }
    }

    func launch(_ app: MapApp, keyword: String, openURL: OpenURLAction) {
        guard let url = app.url(keyword: keyword) else { toast = MapOpenPlan.openFailedMessage(app); return }
        openURL(url) { accepted in if !accepted { Task { @MainActor in self.toast = MapOpenPlan.openFailedMessage(app) } } }
    }
}
