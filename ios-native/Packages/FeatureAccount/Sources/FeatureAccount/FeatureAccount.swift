import GxuStorage
import SwiftUI

/// Phase 0 占位，之后由对应 Agent 接管。
public enum AccountFeature {
    public static let migrations = FeatureMigrations(feature: "account") { _ in }

    @MainActor
    public static func makeRootView() -> some View {
        Text("FeatureAccount")
    }
}
