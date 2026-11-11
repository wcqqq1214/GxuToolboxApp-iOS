import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage

public struct SelectedCourse: Codable, Hashable, Sendable, Identifiable {
    public var classId: String
    public var courseId: String
    public var courseName: String
    public var type: String
    public var selectionType: String
    public var classification: String
    public var belongTo: String
    public var system: String
    public var teacher: String
    public var teacherId: String
    public var credit: Double
    public var year: Int
    public var term: Int
    public var location: String

    public var id: String { "\(year)-\(term)-\(classId)" }

    public var isOnline: Bool { belongTo.contains("网络") || teacher == "网络教师" || teacherId == "000000" }
    public var isLab: Bool { type == "实验" }

    public init(
        classId: String, courseId: String = "", courseName: String, type: String = "", selectionType: String = "",
        classification: String = "", belongTo: String = "", system: String = "", teacher: String = "", teacherId: String = "",
        location: String = "", credit: Double, year: Int, term: Int
    ) {
        self.classId = classId
        self.courseId = courseId
        self.courseName = courseName
        self.type = type
        self.selectionType = selectionType
        self.classification = classification
        self.belongTo = belongTo
        self.system = system
        self.teacher = teacher
        self.teacherId = teacherId
        self.location = location
        self.credit = credit
        self.year = year
        self.term = term
    }

    private enum CodingKeys: String, CodingKey {
        case classId, courseId, courseName, type, selectionType, classification, belongTo, system, teacher, teacherId, location, credit, year, term
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        classId = c.lenientText(.classId)
        courseId = c.lenientText(.courseId)
        courseName = c.lenientText(.courseName)
        type = c.lenientText(.type)
        selectionType = c.lenientText(.selectionType)
        classification = c.lenientText(.classification)
        belongTo = c.lenientText(.belongTo)
        system = c.lenientText(.system)
        teacher = c.lenientText(.teacher)
        teacherId = c.lenientText(.teacherId)
        location = c.lenientText(.location)
        credit = c.lenientNumber(.credit) ?? 0
        year = c.lenientInt(.year) ?? 0
        term = c.lenientInt(.term) ?? 0
    }
}

private extension KeyedDecodingContainer {
    func lenientText(_ key: Key) -> String {
        if let v = try? decodeIfPresent(String.self, forKey: key) { return v.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return String(v) }
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return String(v) }
        return ""
    }

    func lenientInt(_ key: Key) -> Int? {
        guard let v = lenientNumber(key), abs(v) < 1e15 else { return nil }
        return Int(v)
    }

    func lenientNumber(_ key: Key) -> Double? {
        if let v = try? decodeIfPresent(Double.self, forKey: key), v.isFinite { return v }
        if let v = try? decodeIfPresent(String.self, forKey: key), let d = Double(v.trimmingCharacters(in: .whitespaces)), d.isFinite { return d }
        return nil
    }
}

public enum SelectedCourseScope: Hashable, Sendable {
    case all
    case term(AcademicTerm)
}

struct SelectedCoursePage: Decodable, Sendable {
    var items: [SelectedCourse]
}

public struct SelectedCourseAPI: Sendable {
    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    public func list(_ scope: SelectedCourseScope) async throws -> [SelectedCourse] {
        var query: [String: String] = [:]
        if case .term(let t) = scope {
            query = ["year": String(t.year), "term": String(t.term)]
        }
        let page = try await backend.getData("/jw/selected-courses", query: query, as: SelectedCoursePage?.self)
        return page?.items ?? []
    }
}

struct SelectedCourseRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "selected_course"
    var studentId: String
    var year: Int
    var term: Int
    var classId: String
    var courseId: String
    var courseName: String
    var type: String
    var selectionType: String
    var classification: String
    var belongTo: String
    var system: String
    var teacher: String
    var teacherId: String
    var location: String
    var credit: Double
    var updatedAt: Date
}

public struct SelectedCourseRepository: Sendable {
    let database: AppDatabase

    public init(database: AppDatabase) { self.database = database }

    static func registerMigrations(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("course.v1.createSelectedCourse") { db in
            try db.create(table: "selected_course") { t in
                t.column("studentId", .text).notNull()
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("classId", .text).notNull()
                t.column("courseId", .text).notNull()
                t.column("courseName", .text).notNull()
                t.column("type", .text).notNull()
                t.column("selectionType", .text).notNull()
                t.column("classification", .text).notNull()
                t.column("belongTo", .text).notNull()
                t.column("system", .text).notNull()
                t.column("teacher", .text).notNull()
                t.column("teacherId", .text).notNull()
                t.column("credit", .double).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.primaryKey(["studentId", "year", "term", "classId"])
            }
        }
        migrator.registerMigration("course.v2.addSelectedCourseLocation") { db in
            try db.alter(table: "selected_course") { t in
                t.add(column: "location", .text).notNull().defaults(to: "")
            }
        }
    }

    public func list(studentId: String, scope: SelectedCourseScope) async throws -> [SelectedCourse] {
        try await database.writer.read { db in
            var request = SelectedCourseRecord.filter(Column("studentId") == studentId)
            if case .term(let t) = scope { request = request.filter(Column("year") == t.year && Column("term") == t.term) }
            return try request.order(Column("year").desc, Column("term").desc, Column("courseName")).fetchAll(db).map(Self.course)
        }
    }

    public func replaceAll(_ items: [SelectedCourse], studentId: String, now: Date = .now) async throws {
        let rows = try Self.rows(items, studentId: studentId, now: now)
        try await database.writer.write { db in
            try SelectedCourseRecord.filter(Column("studentId") == studentId).deleteAll(db)
            for row in rows { try row.save(db) }
        }
    }

    public func replaceTerm(_ items: [SelectedCourse], studentId: String, term: AcademicTerm, now: Date = .now) async throws {
        if let bad = items.first(where: { $0.year != term.year || $0.term != term.term }) {
            throw GxuError.invalidData("已选课程返回范围不一致：请求 \(term.year)/\(term.term)，实际 \(bad.year)/\(bad.term)")
        }
        let rows = try Self.rows(items, studentId: studentId, now: now)
        try await database.writer.write { db in
            try SelectedCourseRecord
                .filter(Column("studentId") == studentId && Column("year") == term.year && Column("term") == term.term)
                .deleteAll(db)
            for row in rows { try row.save(db) }
        }
    }

    private static func rows(_ items: [SelectedCourse], studentId: String, now: Date) throws -> [SelectedCourseRecord] {
        var index: [String: Int] = [:]
        var rows: [SelectedCourseRecord] = []
        for c in items {
            guard !c.classId.isEmpty else { throw GxuError.invalidData("已选课程缺少教学班标识") }
            guard (1...3).contains(c.term), c.year > 0 else { throw GxuError.invalidData("已选课程学年学期无效：\(c.year)/\(c.term)") }
            let row = SelectedCourseRecord(
                studentId: studentId, year: c.year, term: c.term, classId: c.classId, courseId: c.courseId,
                courseName: c.courseName, type: c.type, selectionType: c.selectionType, classification: c.classification,
                belongTo: c.belongTo, system: c.system, teacher: c.teacher, teacherId: c.teacherId, location: c.location, credit: c.credit, updatedAt: now
            )
            if let i = index[c.id] { rows[i] = row } else { index[c.id] = rows.count; rows.append(row) }
        }
        return rows
    }

    private static func course(_ r: SelectedCourseRecord) -> SelectedCourse {
        SelectedCourse(
            classId: r.classId, courseId: r.courseId, courseName: r.courseName, type: r.type, selectionType: r.selectionType,
            classification: r.classification, belongTo: r.belongTo, system: r.system, teacher: r.teacher, teacherId: r.teacherId,
            location: r.location, credit: r.credit, year: r.year, term: r.term
        )
    }
}
