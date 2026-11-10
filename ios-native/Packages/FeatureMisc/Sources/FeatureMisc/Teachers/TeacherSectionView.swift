import SwiftUI

/// 详情页的一个分组。学历、联系方式这类「标签：值」的分组用左右两列显示，其余是整段文字。
struct TeacherSectionView: View {
    let section: TeacherSection

    /// 只有 `lines(...)` 拼出来的两个分组按「标签：值」解析；任何一行解析不了就整段当文字，不丢内容
    private var rows: [(label: String, value: String)]? {
        guard section.id == "education" || section.id == "contact" else { return nil }
        let lines = section.text.split(separator: "\n", omittingEmptySubsequences: true)
        let parsed = lines.compactMap { line -> (label: String, value: String)? in
            guard let separator = line.range(of: "：") else { return nil }
            return (String(line[..<separator.lowerBound]), String(line[separator.upperBound...]))
        }
        return parsed.count == lines.count && !parsed.isEmpty ? parsed : nil
    }

    var body: some View {
        Section(section.title) {
            if let rows {
                ForEach(rows, id: \.label) { row in
                    LabeledContent(row.label) {
                        Text(row.value).multilineTextAlignment(.trailing).textSelection(.enabled)
                    }
                }
            } else {
                Text(section.text).lineSpacing(4).textSelection(.enabled)
            }
        }
    }
}
