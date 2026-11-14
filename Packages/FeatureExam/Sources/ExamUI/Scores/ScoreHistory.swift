import ExamKit
import Foundation

enum ScoreHistory {
    static func matching(_ scores: [Score], query: String) -> [Score] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return scores.filter {
            query.isEmpty || $0.courseName.localizedStandardContains(query) || $0.teacherName.localizedStandardContains(query)
        }
    }

    static func title(for group: ScoreGroup) -> String {
        if group.term == 0 { return "\(group.year)–\(group.year + 1) · 未标明学期" }
        if group.term > 2 { return "\(group.year)–\(group.year + 1) · 其他学期（\(group.term)）" }
        return group.title
    }
}
