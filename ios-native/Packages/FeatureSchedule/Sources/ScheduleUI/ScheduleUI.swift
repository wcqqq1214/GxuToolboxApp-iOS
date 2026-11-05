import GxuStorage
import ScheduleKit
import SwiftUI

public enum ScheduleFeature {
    public static var migrations: FeatureMigrations { ScheduleKit.migrations }

    /// - Parameter onRequestLogin: 未登录时空状态里的“去登录”按钮
    @MainActor
    public static func makeRootView(onRequestLogin: @escaping @MainActor () -> Void = {}) -> some View {
        ScheduleRootView(onRequestLogin: onRequestLogin)
    }
}
