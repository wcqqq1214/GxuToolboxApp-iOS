import ExamKit
import GxuDesign
import GxuFoundation
import SwiftUI

struct TermMenu: View {
    let years: [Int]
    @Binding var year: Int
    @Binding var term: Int?
    var allowsWholeYear = false
    var isAll: Binding<Bool>?

    private var termName: String {
        switch term {
        case 1: "秋季"
        case 2: "春季"
        default: "全学年"
        }
    }

    private var labelText: String {
        isAll?.wrappedValue == true ? "全部学期" : "\(year)–\(year + 1) \(termName)"
    }

    var body: some View {
        LabeledContent("学期") {
            Menu {
                if let isAll {
                    Picker("范围", selection: isAll) {
                        Text("全部学期").tag(true)
                        Text("按学年 / 学期").tag(false)
                    }
                    Divider()
                }
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
                HStack(spacing: 4) {
                    Text(verbatim: labelText)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
                }
            }
        }
        .accessibilityLabel("选择学年和学期")
    }
}

struct LoadKey<Value: Hashable>: Hashable {
    var value: Value
    var ready: Bool
}

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
