#if DEBUG
import FeatureAccount
import GxuFoundation
import FeatureCourse
import FeatureMisc
import SwiftUI

/// DEBUG：`-GxuScreen feedback|feedbackList|profile|attendance|unified|oaFiles|oaFilesDemo|oaDetailDemo|oaAccount|errorLog|web` 直接打开 A 负责的页面（截图自查用）。
/// `web` 可再带 `-GxuWebURL <url>`。
enum DebugScreens {
    static var requested: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-GxuScreen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    @MainActor @ViewBuilder
    static func view(for name: String) -> some View {
        NavigationStack {
            switch name {
            case "feedback": AccountFeature.makeFeedbackView()
            case "feedbackList": FeedbackListView()
            case "profile": AccountFeature.makePersonalInfoView()
            case "attendance": AccountFeature.makeAttendanceAccountView()
            case "unified": AccountFeature.makeUnifiedAccountView()
            case "oaFiles": AccountFeature.makeOAFilesView()
            case "oaFilesDemo": AccountFeature.makeOAFilesDemoView()
            case "oaDetailDemo": AccountFeature.makeOAFileDetailDemoView()
            case "oaAccount": AccountFeature.makeOAAccountView()
            case "errorLog":
                // 截图用：先写几条示例记录（包含会被脱敏的内容，验证脱敏效果）
                let _ = {
                    ErrorLog.shared.record("network", "GET /jw/exam?year=2025&term=1 → HTTP 500")
                    ErrorLog.shared.record("auth", "login failed for 2200000000 password=hunter2 Authorization: Bearer abc.def.ghi")
                }()
                AccountFeature.makeErrorLogView()
            case let name where CourseDebugScreens.handles(name): CourseDebugScreens.view(for: name)
            case let name where MiscDebugScreens.handles(name): MiscDebugScreens.view(for: name)
            default:
                let args = ProcessInfo.processInfo.arguments
                let text = args.firstIndex(of: "-GxuWebURL").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? "https://www.gxu.edu.cn"
                AccountFeature.makeWebView(url: URL(string: text)!)
            }
        }
    }
}
#endif
