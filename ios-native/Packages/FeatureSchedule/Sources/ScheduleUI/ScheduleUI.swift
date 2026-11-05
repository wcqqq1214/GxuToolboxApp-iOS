import GxuStorage
import ScheduleKit
import SwiftUI

/// Phase 0 占位，之后由 Agent B 接管。
public enum ScheduleFeature {
    public static var migrations: FeatureMigrations { ScheduleKit.migrations }

    @MainActor
    public static func makeRootView() -> some View {
        Text("课表")
    }
}
