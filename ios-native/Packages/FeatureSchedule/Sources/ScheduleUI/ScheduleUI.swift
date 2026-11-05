import GxuStorage
import ScheduleKit
import SwiftUI

public enum ScheduleFeature {
    public static var migrations: FeatureMigrations { ScheduleKit.migrations }

    /// 工具箱 →「导出课表」
    @MainActor
    public static func makeExportView() -> some View { ExportScheduleView() }

    /// - Parameter onRequestLogin: 未登录时空状态里的“去登录”按钮
    @MainActor
    public static func makeRootView(onRequestLogin: @escaping @MainActor () -> Void = {}) -> some View {
        ScheduleRootView(onRequestLogin: onRequestLogin)
    }
}
