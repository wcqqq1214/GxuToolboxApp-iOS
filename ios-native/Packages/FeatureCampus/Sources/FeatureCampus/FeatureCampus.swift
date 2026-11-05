import GxuStorage
import SwiftUI

public enum CampusFeature {
    public static let migrations = FeatureMigrations(feature: "campus") { _ in }

    /// 工具箱 → 班级课表
    @MainActor
    public static func makeClassScheduleView() -> some View { ClassScheduleView() }

    /// 工具箱 → 全校课表
    @MainActor
    public static func makeFullScheduleView() -> some View { FullScheduleView() }

    @MainActor
    public static func makeRootView() -> some View { makeClassScheduleView() }
}
