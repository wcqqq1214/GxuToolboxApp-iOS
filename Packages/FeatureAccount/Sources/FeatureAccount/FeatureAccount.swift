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

    /// 设置 → 统一认证账号（CA；PEC、工程训练中心的登录依赖它）
    @MainActor
    public static func makeUnifiedAccountView() -> some View {
        JwAccountView(system: .unified)
    }

    /// 设置 → 个人信息
    @MainActor
    public static func makePersonalInfoView() -> some View { PersonalInfoView() }

    /// 设置 → 意见反馈（页面右上角进入「我的反馈」）
    @MainActor
    public static func makeFeedbackView() -> some View { FeedbackView() }

    /// WebView 容器。`cookies` 会在加载前写入；`window.open` / `target=_blank` 会推入新页面（外层需要 NavigationStack）。
    @MainActor
    public static func makeWebView(url: URL, title: String? = nil, cookies: [HTTPCookie] = []) -> some View {
        WebViewScreen(url: url, title: title, cookies: cookies)
    }

    /// 工具箱 → OA 文件（列表 / 搜索 / 详情 / 附件预览；右上角菜单里有「旧系统待阅文件」）
    @MainActor
    public static func makeOAFilesView() -> some View { OAFilesView() }

    /// 设置 → OA 账号（OA 文件和问卷系统共用）
    @MainActor
    public static func makeOAAccountView() -> some View { JwAccountView(system: .oa) }

    /// 设置 → 诊断日志（本机脱敏的错误日志，可分享 / 清除，不会自动上传）
    @MainActor
    public static func makeErrorLogView() -> some View { ErrorLogView() }

    #if DEBUG
    /// DEBUG 截图用：OA 文件列表（示例数据，不联网）
    @MainActor
    public static func makeOAFilesDemoView() -> some View { OAFilesView(demo: true) }

    /// DEBUG 截图用：OA 文件详情（示例数据，不联网）
    @MainActor
    public static func makeOAFileDetailDemoView() -> some View {
        OAFileDetailView(row: OAFilesModel.demo(services: .unconfigured).rows[0], demo: true)
    }
    #endif
}
