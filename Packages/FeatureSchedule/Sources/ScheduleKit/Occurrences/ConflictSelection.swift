import Foundation
import GxuFoundation
import GxuStorage

extension ConflictGroup {
    public var key: String { ScheduleExpander.conflictKey(self).joined(separator: "\u{1F}") }

    public func selected(choices: [String: String]) -> CourseOccurrence {
        guard isConflict, !choices.isEmpty else { return items[0] }
        if let choice = choices[key] {
            return items.first { ScheduleExpander.selectionKey($0.course) == choice } ?? items[0]
        }
        let legacyKey = items.map(\.course.legacyID).sorted().joined(separator: "\u{1F}")
        guard let choice = choices[legacyKey] else { return items[0] }
        let matches = items.filter { $0.course.legacyID == choice }
        return matches.count == 1 ? matches[0] : items[0]
    }
}

public enum ConflictResolver {
    public static func resolve(_ occurrences: [CourseOccurrence], choices: [String: String]) -> [CourseOccurrence] {
        var result: [CourseOccurrence] = []
        struct Domain: Hashable { var date: Date; var isMakeup: Bool }
        for (_, sameDay) in Dictionary(grouping: occurrences, by: { Domain(date: $0.date, isMakeup: $0.isMakeup) }) {
            for group in ScheduleExpander.conflictGroups(sameDay) {
                result.append(group.selected(choices: choices))
            }
        }
        return result.sorted { ($0.startsAt, $0.id) < ($1.startsAt, $1.id) }
    }
}

extension ScheduleRepository {
    public func conflictChoices(studentId: String, term: AcademicTerm) async -> [String: String] {
        let pairs = await ErrorLog.shared.attempt("cache", "读取冲突课程选择失败") {
            try await database.writer.read { db -> [[String]] in
                try Row.fetchAll(
                    db, sql: "SELECT groupKey, choice FROM schedule_conflict_choice WHERE studentId = ? AND year = ? AND term = ?",
                    arguments: [studentId, term.year, term.term]
                ).map { [$0["groupKey"], $0["choice"]] }
            }
        }
        return Dictionary(uniqueKeysWithValues: (pairs ?? []).map { ($0[0], $0[1]) })
    }

    public func setConflictChoice(_ choice: String, groupKey: String, studentId: String, term: AcademicTerm) async throws {
        try await database.writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO schedule_conflict_choice (studentId, year, term, groupKey, choice) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(studentId, year, term, groupKey) DO UPDATE SET choice = excluded.choice
                """,
                arguments: [studentId, term.year, term.term, groupKey, choice]
            )
        }
    }
}
