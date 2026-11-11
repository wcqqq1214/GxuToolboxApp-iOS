import Foundation
import ScheduleKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum MapNavigation {
    @MainActor
    public static func installedApps() -> [MapApp] {
        #if DEBUG
        if CommandLine.arguments.contains("-GxuMapAllApps") { return MapApp.allCases }
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

    @MainActor
    public static func plan(text: String, keyword: String? = nil, installed: [MapApp]? = nil) -> MapOpenPlan {
        let direct = keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parsed = direct.isEmpty ? CampusPlaces.parse(text)?.fullName : nil
        return MapOpenPlan.make(keyword: direct, parsedFullName: parsed, installed: installed ?? installedApps())
    }
}

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
