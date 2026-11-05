import GxuStorage
import SwiftUI

public enum ExamFeature {
    public static let migrations = ExamRepository.migrations

    @MainActor
    public static func makeRootView() -> some View {
        Text("FeatureExam")
    }
}
