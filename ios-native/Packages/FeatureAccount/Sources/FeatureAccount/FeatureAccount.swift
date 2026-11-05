import GxuStorage
import SwiftUI

public enum AccountFeature {
    public static let migrations = FeatureMigrations(feature: "account") { _ in }

    /// 设置 → 教务账号。由设置页（Shell）以导航目标的形式挂载。
    @MainActor
    public static func makeRootView() -> some View {
        JwAccountView()
    }

    /// 设置 → 考勤账号（验证码登录）。同样以导航目标挂载，自带 `navigationTitle`。
    @MainActor
    public static func makeAttendanceAccountView() -> some View {
        AttendanceAccountView()
    }
}
