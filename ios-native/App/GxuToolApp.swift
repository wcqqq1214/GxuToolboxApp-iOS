import ClassWidgetKit
import FeatureAccount
import GxuAuth
import GxuFoundation
import SwiftUI

@main
struct GxuToolApp: App {
    private let services = AppComposition.live()

    init() {
        // 未捕获的异常也记进本机日志（已脱敏，只有异常名和原因）
        NSSetUncaughtExceptionHandler { exception in
            ErrorLog.shared.record("crash", "\(exception.name.rawValue): \(exception.reason ?? "")")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let name = DebugScreens.requested { DebugScreens.view(for: name) } else { RootView() }
                #else
                RootView()
                #endif
            }
                .environment(\.services, services)
                .promptForUpdates()
                #if !DEBUG
                .task { services.track("open_app", feature: "app") }   // 开发构建不上报埋点，避免污染线上数据
                #endif
                .task { await WidgetBridge.run(services: services) }
                #if DEBUG
                .task { await DebugAutoLogin.runIfRequested(services.accounts) }
                #endif
        }
    }
}
