import FeatureAccount
import SwiftUI

/// 教务原站提供个人课表与班级课表，用户可以将当前页面保存为 HTML。
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

            WebViewScreen(url: tab.url, title: "导出课表", allowsHTMLExport: true)
                .id(tab)
        }
    }
}
