import SwiftUI

/// 学年 + 学期选择。`term == nil` 表示全学年（仅 `allowsWholeYear` 时可选）
struct TermPicker: View {
    @Binding var year: Int
    @Binding var term: Int?
    var allowsWholeYear = false

    // TEMP(coord-1): 入学年份 / 学制由 A 提供前，取最近 4 个学年
    private let years = TermOptions.years(enrollmentYear: nil)

    var body: some View {
        HStack {
            Picker("学年", selection: $year) {
                ForEach(years, id: \.self) { Text(verbatim: "\($0)-\($0 + 1) 学年").tag($0) }
            }
            Picker("学期", selection: $term) {
                Text("秋季").tag(Int?.some(1))
                Text("春季").tag(Int?.some(2))
                if allowsWholeYear { Text("全学年").tag(Int?.none) }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
            Spacer()
            if let retry { Button("重试", action: retry).font(.footnote) }
        }
        .foregroundStyle(.red)
    }
}

func syncText(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MM月dd日 HH:mm:ss"
    return f.string(from: date)
}
