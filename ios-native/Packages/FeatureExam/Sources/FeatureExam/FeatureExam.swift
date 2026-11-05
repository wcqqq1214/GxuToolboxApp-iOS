import GxuStorage
import SwiftUI

/// Phase 0 占位，之后由对应 Agent 接管。
public enum ExamFeature {
    public static let migrations = FeatureMigrations(feature: "exam") { _ in }

    @MainActor
    public static func makeRootView() -> some View {
        Text("FeatureExam")
    }
}
