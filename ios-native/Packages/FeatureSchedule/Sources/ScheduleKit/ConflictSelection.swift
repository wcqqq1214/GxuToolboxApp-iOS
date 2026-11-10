import Foundation
import GxuFoundation
import GxuStorage

extension ConflictGroup {
    /// 冲突组的稳定标识，用来存“选中哪一门”。组内课程 key 排序后拼接
    public var key: String { ScheduleExpander.conflictKey(self).joined(separator: "\u{1F}") }

    /// 用户选中的那一门；没选过（或选的课已不在组里）取组内第一门
    public func selected(choices: [String: String]) -> CourseOccurrence {
        if let choice = choices[key], let hit = items.first(where: { ScheduleExpander.selectionKey($0.course) == choice }) { return hit }
        return items[0]
    }
}

public enum ConflictResolver {
    /// 每个冲突组只保留选中的那一门，给“今天 / 下一节课 / 小组件”这类一次只能上一门课的场景用。
    /// 周网格仍然显示整组（带角标），不要用这个。
    public static func resolve(_ occurrences: [CourseOccurrence], choices: [String: String]) -> [CourseOccurrence] {
        var result: [CourseOccurrence] = []
        // 同一天里，补课日被调过来的课和原有的课是两个独立的冲突域（RN v2.2：两组各自合并，不互相吞并）
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
    /// 本账号在某学期的冲突选择：`ConflictGroup.key` → 选中课程的 `selectionKey`
    public func conflictChoices(studentId: String, term: AcademicTerm) async -> [String: String] {
        let pairs = try? await database.writer.read { db -> [[String]] in
            try Row.fetchAll(
                db, sql: "SELECT groupKey, choice FROM schedule_conflict_choice WHERE studentId = ? AND year = ? AND term = ?",
                arguments: [studentId, term.year, term.term]
            ).map { [$0["groupKey"], $0["choice"]] }
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
