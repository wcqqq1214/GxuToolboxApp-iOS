import GxuStorage
import SwiftUI

/// Phase 0 占位，之后由对应 Agent 接管。
public enum CampusFeature {
    public static let migrations = FeatureMigrations(feature: "campus") { _ in }

    @MainActor
    public static func makeRootView() -> some View {
        Text("FeatureCampus")
    }
}
