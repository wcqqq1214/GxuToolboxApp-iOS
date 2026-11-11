import GxuStorage
import SwiftUI

public enum AccountFeature {
    public static let migrations = FeatureMigrations(feature: "account") { _ in }

    @MainActor
    public static func makeRootView() -> some View {
        JwAccountView()
    }

    @MainActor
    public static func makeAttendanceAccountView() -> some View {
        AttendanceAccountView()
    }

    @MainActor
    public static func makeUnifiedAccountView() -> some View {
        JwAccountView(system: .unified)
    }

    @MainActor
    public static func makePersonalInfoView() -> some View { PersonalInfoView() }

    @MainActor
    public static func makeFeedbackView() -> some View { FeedbackView() }

    @MainActor
    public static func makeWebView(url: URL, title: String? = nil, cookies: [HTTPCookie] = []) -> some View {
        WebViewScreen(url: url, title: title, cookies: cookies)
    }

    @MainActor
    public static func makeOAFilesView() -> some View { OAFilesView() }

    @MainActor
    public static func makeOAAccountView() -> some View { JwAccountView(system: .oa) }

    @MainActor
    public static func makeErrorLogView() -> some View { ErrorLogView() }

    #if DEBUG
    @MainActor
    public static func makeOAFilesDemoView() -> some View { OAFilesView(demo: true) }

    @MainActor
    public static func makeOAFileDetailDemoView() -> some View {
        OAFileDetailView(row: OAFilesModel.demo(services: .unconfigured).rows[0], demo: true)
    }
    #endif
}
