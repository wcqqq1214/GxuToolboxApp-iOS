import GxuFoundation
import SwiftUI

@main
struct GxuToolApp: App {
    init() {
        NSSetUncaughtExceptionHandler { exception in
            ErrorLog.shared.record("crash", "\(exception.name.rawValue): \(exception.reason ?? "")")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppStartupView()
        }
    }
}
