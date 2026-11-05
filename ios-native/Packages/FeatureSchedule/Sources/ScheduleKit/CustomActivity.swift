import Foundation
import GxuFoundation
import GxuStorage

/// 用户自己添加的日程（社团活动、兼职、自习等）。显示上和课程一样占课表的格子，带“自定义”标记。
public struct CustomActivity: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var note: String
    /// 1 = 周一 … 7 = 周日
    public var weekday: Int
    public var begin: Int
    public var end: Int
    public var weekFrom: Int
    public var weekTo: Int
    /// 0xRRGGBB
    public var colorHex: UInt32

    public init(
        id: String = UUID().uuidString, name: String = "新日程", note: String = "", weekday: Int = 1,
        begin: Int = 1, end: Int = 2, weekFrom: Int = 1, weekTo: Int = 1, colorHex: UInt32 = 0xB5EAD7
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.weekday = weekday
        self.begin = begin
        self.end = end
        self.weekFrom = weekFrom
        self.weekTo = weekTo
        self.colorHex = colorHex
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (1...7).contains(weekday)
            && (1...ClassPeriods.count).contains(begin) && (begin...ClassPeriods.count).contains(end)
            && weekFrom >= 1 && weekFrom <= weekTo
    }

    /// 周次文案：“仅第 3 周” / “第 3–8 周”
    public var weekText: String { weekFrom == weekTo ? "仅第 \(weekFrom) 周" : "第 \(weekFrom)–\(weekTo) 周" }

    /// 转成一门“课”，让展开、冲突、节假日叠加、今日 / 下一节课全部沿用课程的逻辑
    public var course: TheoryCourse {
        TheoryCourse(
            sectionRange: "\(begin)-\(end)", begin: begin, end: end, courseName: name.trimmingCharacters(in: .whitespaces),
            weeks: Array(weekFrom...max(weekFrom, weekTo)), courseCategory: "自定义日程", examMethod: note,
            weekday: weekday, customID: id
        )
    }
}

extension ScheduleRepository {
    public func customActivities(studentId: String, term: AcademicTerm) async -> [CustomActivity] {
        let blobs = try? await database.writer.read { db -> [Data] in
            try Row.fetchAll(
                db, sql: "SELECT json FROM schedule_custom_activity WHERE studentId = ? AND year = ? AND term = ?",
                arguments: [studentId, term.year, term.term]
            ).map { $0["json"] }
        }
        return (blobs ?? []).compactMap { try? JSONDecoder().decode(CustomActivity.self, from: $0) }
            .sorted { ($0.weekFrom, $0.weekday, $0.begin, $0.id) < ($1.weekFrom, $1.weekday, $1.begin, $1.id) }
    }

    /// 新增或覆盖（按 id）
    public func saveCustomActivity(_ activity: CustomActivity, studentId: String, term: AcademicTerm) async throws {
        let json = try JSONEncoder().encode(activity)
        try await database.writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO schedule_custom_activity (studentId, year, term, id, json) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(studentId, year, term, id) DO UPDATE SET json = excluded.json
                """,
                arguments: [studentId, term.year, term.term, activity.id, json]
            )
        }
    }

    public func deleteCustomActivity(id: String, studentId: String, term: AcademicTerm) async throws {
        try await database.writer.write { db in
            try db.execute(
                sql: "DELETE FROM schedule_custom_activity WHERE studentId = ? AND year = ? AND term = ? AND id = ?",
                arguments: [studentId, term.year, term.term, id]
            )
        }
    }
}
