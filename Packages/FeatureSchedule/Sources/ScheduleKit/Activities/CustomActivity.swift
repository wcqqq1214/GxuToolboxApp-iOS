import Foundation
import GxuFoundation
import GxuStorage

public struct CustomActivity: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var note: String
    public var location: String
    public var teacher: String
    public var weekday: Int
    public var begin: Int
    public var end: Int
    public var weeks: [Int] { didSet { weeks = Self.normalized(weeks) } }
    public var colorHex: UInt32

    public var weekFrom: Int { weeks.first ?? 1 }
    public var weekTo: Int { weeks.last ?? weekFrom }

    public init(
        id: String = UUID().uuidString, name: String = "", note: String = "", location: String = "", teacher: String = "",
        weekday: Int = 1, begin: Int = 1, end: Int = 2, weekFrom: Int = 1, weekTo: Int = 1, weeks: [Int]? = nil, colorHex: UInt32 = 0xB5EAD7
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.location = location
        self.teacher = teacher
        self.weekday = weekday
        self.begin = begin
        self.end = end
        self.weeks = Self.normalized(weeks ?? (weekFrom <= weekTo ? Array(weekFrom...weekTo) : []))
        self.colorHex = colorHex
    }

    private enum CodingKeys: String, CodingKey { case id, name, note, location, teacher, weekday, begin, end, weekFrom, weekTo, weeks, colorHex }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let from = try c.decodeIfPresent(Int.self, forKey: .weekFrom) ?? 1
        let to = try c.decodeIfPresent(Int.self, forKey: .weekTo) ?? from
        self.init(
            id: try c.decode(String.self, forKey: .id), name: try c.decode(String.self, forKey: .name),
            note: try c.decodeIfPresent(String.self, forKey: .note) ?? "",
            location: try c.decodeIfPresent(String.self, forKey: .location) ?? "",
            teacher: try c.decodeIfPresent(String.self, forKey: .teacher) ?? "",
            weekday: try c.decode(Int.self, forKey: .weekday), begin: try c.decode(Int.self, forKey: .begin), end: try c.decode(Int.self, forKey: .end),
            weeks: try c.decodeIfPresent([Int].self, forKey: .weeks) ?? (from >= 1 && from <= to && to <= 60 ? Array(from...to) : []),
            colorHex: try c.decode(UInt32.self, forKey: .colorHex)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(note, forKey: .note)
        try c.encode(location, forKey: .location)
        try c.encode(teacher, forKey: .teacher)
        try c.encode(weekday, forKey: .weekday)
        try c.encode(begin, forKey: .begin)
        try c.encode(end, forKey: .end)
        try c.encode(weekFrom, forKey: .weekFrom)
        try c.encode(weekTo, forKey: .weekTo)
        try c.encode(weeks, forKey: .weeks)
        try c.encode(colorHex, forKey: .colorHex)
    }

    static func normalized(_ weeks: [Int]) -> [Int] { Array(Set(weeks)).sorted() }

    public var isValid: Bool { validationMessage == nil }

    public var validationMessage: String? {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "请输入课程名称" }
        if title.count > 100 { return "名称最多 100 字" }
        if location.trimmingCharacters(in: .whitespacesAndNewlines).count > 200 { return "地点最多 200 字" }
        if teacher.trimmingCharacters(in: .whitespacesAndNewlines).count > 100 { return "教师最多 100 字" }
        if note.trimmingCharacters(in: .whitespacesAndNewlines).count > 2000 { return "备注最多 2000 字" }
        if weeks.isEmpty { return "请选择教学周" }
        if weeks.contains(where: { !(1...53).contains($0) }) { return "教学周须在 1—53 之间" }
        if !(1...7).contains(weekday) { return "请选择星期" }
        if !(1...ClassPeriods.count).contains(begin) || !(1...ClassPeriods.count).contains(end) { return "节次须在 1—\(ClassPeriods.count) 之间" }
        if end < begin { return "结束节次不能早于开始节次" }
        return nil
    }

    public var weekText: String { "第 \(TeachingWeeks.format(weeks)) 周" }

    public var weeksInputText: String { TeachingWeeks.format(weeks) }

    public var course: TheoryCourse {
        TheoryCourse(
            venueName: location.trimmingCharacters(in: .whitespacesAndNewlines), sectionRange: "\(begin)-\(end)", begin: begin, end: end,
            courseName: name.trimmingCharacters(in: .whitespaces), weeks: weeks,
            teacher: teacher.trimmingCharacters(in: .whitespacesAndNewlines), courseCategory: "自定义课程", examMethod: note,
            weekday: weekday, customID: id
        )
    }
}

public enum TeachingWeeks {
    public enum ParseError: Error, Equatable, LocalizedError {
        case format
        case range(weekCount: Int)

        public var errorDescription: String? {
            switch self {
            case .format: "教学周格式示例：1-8,10,12"
            case .range(let count): "教学周须在 1—\(count) 之间"
            }
        }
    }

    public static func parse(_ text: String, weekCount: Int) throws -> [Int] {
        var weeks = Set<Int>()
        for token in text.replacingOccurrences(of: "，", with: ",").split(separator: ",", omittingEmptySubsequences: false) {
            let parts = token.split(separator: "-", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
                  let from = Int(parts[0]), let to = Int(parts[parts.count - 1]) else { throw ParseError.format }
            guard from >= 1, to >= from, to <= weekCount else { throw ParseError.range(weekCount: weekCount) }
            weeks.formUnion(from...to)
        }
        return weeks.sorted()
    }

    public static func format(_ weeks: [Int]) -> String {
        let sorted = Array(Set(weeks)).sorted()
        var parts: [String] = []
        var index = 0
        while index < sorted.count {
            var last = index
            while last + 1 < sorted.count, sorted[last + 1] == sorted[last] + 1 { last += 1 }
            parts.append(last == index ? "\(sorted[index])" : "\(sorted[index])-\(sorted[last])")
            index = last + 1
        }
        return parts.joined(separator: ",")
    }
}

extension ScheduleRepository {
    public func customActivities(studentId: String, term: AcademicTerm) async -> [CustomActivity] {
        let blobs = await ErrorLog.shared.attempt("cache", "读取自定义课程失败") {
            try await database.writer.read { db -> [Data] in
                try Row.fetchAll(
                    db, sql: "SELECT json FROM schedule_custom_activity WHERE studentId = ? AND year = ? AND term = ?",
                    arguments: [studentId, term.year, term.term]
                ).map { $0["json"] }
            }
        }
        return (blobs ?? []).compactMap { blob in
            ErrorLog.shared.attempt("cache", "解码自定义课程失败") { try JSONDecoder().decode(CustomActivity.self, from: blob) }
        }
            .sorted { ($0.weekFrom, $0.weekday, $0.begin, $0.id) < ($1.weekFrom, $1.weekday, $1.begin, $1.id) }
    }

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
