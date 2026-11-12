import ClassWidgetKit
import FeatureAccount
import GxuAuth
import SwiftUI

struct AppStartupView: View {
    @State private var model = AppStartupModel()

    var body: some View {
        Group {
            switch model.state {
            case .idle, .opening:
                ProgressView("正在打开本地数据")
            case .failed(let code):
                DatabaseFailureView(code: code) { await model.start() }
            case .ready(let services):
                content(services: services)
            }
        }
        .task { await model.start() }
    }

    private func content(services: AppServices) -> some View {
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
        .task { services.track("open_app", feature: "app") }
        #endif
        .task { await WidgetBridge.run(services: services) }
        #if DEBUG
        .task { await DebugAutoLogin.runIfRequested(services.accounts) }
        #endif
    }
}
