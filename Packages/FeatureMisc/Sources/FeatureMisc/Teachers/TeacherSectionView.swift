import SwiftUI

struct TeacherSectionView: View {
    let section: TeacherSection

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
