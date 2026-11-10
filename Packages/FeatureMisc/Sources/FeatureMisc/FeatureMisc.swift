import GxuStorage
import SwiftUI

public enum MiscFeature {
    public static let migrations = FeatureMigrations(feature: "misc") { _ in }

    @MainActor
    public static func makeRootView() -> some View {
        AttendanceView()
    }
}
