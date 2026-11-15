import FeatureAccount
import GxuAuth
import GxuDesign
import GxuFoundation
import SwiftUI

struct JwScheduleExportView: View {
    private enum Tab: String, CaseIterable {
        case personal = "个人课表"
        case classroom = "班级课表"

        var url: URL {
            let path = switch self {
            case .personal: "kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default"
            case .classroom: "kbdy/bjkbdy_cxBjkbdyIndex.html?gnmkdm=N214505&layout=default"
            }
            return URL(string: "https://jwxt2018.gxu.edu.cn/jwglxt/" + path)!
        }
    }

    private enum SessionState {
        case loading
        case ready([HTTPCookie])
        case failed(String)
    }

    @Environment(\.services) private var services
    @State private var session: SessionState = .loading
    @State private var attempt = 0
    @State private var tab: Tab

    init(classSchedule: Bool = false) {
        _tab = State(initialValue: classSchedule ? .classroom : .personal)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("课表类型", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch session {
            case .loading:
                GxuLoadingView("正在准备教务登录状态…")
            case .failed(let message):
                GxuErrorView(message) { attempt += 1 }
            case .ready(let cookies):
                WebViewScreen(url: tab.url, title: "教务原版课表", cookies: cookies, allowsHTMLExport: true,
                              onSessionExpired: { attempt += 1 })
                    .id(tab)
            }
        }
        .navigationTitle("教务原版课表")
        .id(services.accounts.jwSessionID)
        .task(id: "\(services.accounts.jwSessionID)-\(attempt)") {
            session = .loading
            do {
                let cookies = try await services.accounts.jwWebSessionCookies(refresh: attempt > 0)
                guard !Task.isCancelled else { return }
                session = .ready(cookies)
            } catch {
                guard !Task.isCancelled else { return }
                session = .failed((error as? GxuError)?.userMessage ?? error.localizedDescription)
            }
        }
    }
}
