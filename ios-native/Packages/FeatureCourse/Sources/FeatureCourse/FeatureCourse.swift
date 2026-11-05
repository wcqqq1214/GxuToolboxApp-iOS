import GxuStorage
import SwiftUI

public enum CourseFeature {
    public static let migrations = FeatureMigrations(feature: "course") { _ in }

    @MainActor
    public static func makeRootView() -> some View {
        List {
            NavigationLink { HolidayView() } label: { Label("节假日", systemImage: "sun.max") }
            NavigationLink { TimeShiftView() } label: { Label("调休补班", systemImage: "calendar.badge.clock") }
        }
        .navigationTitle("课程与通知")
    }
}
