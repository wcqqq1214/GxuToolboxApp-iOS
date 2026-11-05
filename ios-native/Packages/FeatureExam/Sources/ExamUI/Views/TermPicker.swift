import ExamKit
import GxuDesign
import GxuFoundation
import SwiftUI

/// 学年 + 学期选择，放在工具栏里的紧凑菜单。`term == nil` 表示全学年（仅 `allowsWholeYear` 时可选）
struct TermMenu: View {
    let years: [Int]
    @Binding var year: Int
    @Binding var term: Int?
    var allowsWholeYear = false

    private var termName: String {
        switch term {
        case 1: "秋季"
        case 2: "春季"
        default: "全学年"
        }
    }

    var body: some View {
        Menu {
            Picker("学年", selection: $year) {
                ForEach(years.contains(year) ? years : (years + [year]).sorted(), id: \.self) {
                    Text(verbatim: "\($0)–\($0 + 1) 学年").tag($0)
                }
            }
            Picker("学期", selection: $term) {
                Text("秋季").tag(Int?.some(1))
                Text("春季").tag(Int?.some(2))
                if allowsWholeYear { Text("全学年").tag(Int?.none) }
            }
        } label: {
            Label {
                Text(verbatim: "\(year)–\(year + 1) · \(termName)")
            } icon: {
                Image(systemName: "calendar")
            }
        }
        .accessibilityLabel("选择学年和学期")
    }
}

/// `.task(id:)` 的键：默认学期解析完成（`ready`）后才触发首次加载
struct LoadKey<Value: Hashable>: Hashable {
    var value: Value
    var ready: Bool
}

/// 有缓存时用非阻塞提示，没有缓存才整页显示错误
@MainActor @ViewBuilder
func errorSection(_ error: GxuError?, hasData: Bool, updatedAt: Date? = nil, retry: @escaping () -> Void) -> some View {
    if let error {
        if hasData {
            GxuStaleBanner(updatedAt: updatedAt, message: error.userMessage)
        } else {
            GxuErrorView(error.userMessage, retry: retry)
        }
    }
}

func syncText(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "M月d日 HH:mm"
    return f.string(from: date)
}
