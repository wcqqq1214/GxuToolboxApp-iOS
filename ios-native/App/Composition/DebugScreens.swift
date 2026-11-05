#if DEBUG
import FeatureAccount
import FeatureCourse
import SwiftUI

/// DEBUG：`-GxuScreen feedback|feedbackList|profile|attendance|unified|web` 直接打开 A 负责的页面（截图自查用）。
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
            case let name where CourseDebugScreens.handles(name): CourseDebugScreens.view(for: name)
            default:
                let args = ProcessInfo.processInfo.arguments
                let text = args.firstIndex(of: "-GxuWebURL").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? "https://www.gxu.edu.cn"
                AccountFeature.makeWebView(url: URL(string: text)!)
            }
        }
    }
}
#endif
