import GxuAuth
import SwiftUI

@main
struct GxuToolApp: App {
    private let services = AppComposition.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.services, services)
                #if DEBUG
                .task { await DebugAutoLogin.runIfRequested(services.accounts) }
                #endif
        }
    }
}
