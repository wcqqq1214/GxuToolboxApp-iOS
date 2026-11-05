import GxuStorage
import SwiftUI

/// Phase 0 占位，之后由对应 Agent 接管。
public enum MiscFeature {
    public static let migrations = FeatureMigrations(feature: "misc") { _ in }

    @MainActor
    public static func makeRootView() -> some View {
        Text("FeatureMisc")
    }
}
