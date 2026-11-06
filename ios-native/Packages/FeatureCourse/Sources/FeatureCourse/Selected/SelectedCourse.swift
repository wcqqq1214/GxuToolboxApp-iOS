import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage

/// `GET /jw/selected-courses` 的一条（后端已用适配器转成统一模型）。
/// 已用真实脱敏响应核对（`Fixtures/sanitized/selected-courses*.json`，测试见 `RealFixtureTests`）；
/// 解码对缺字段、数字写成字符串都宽容。
public struct SelectedCourse: Codable, Hashable, Sendable, Identifiable {
    /// 教学班 ID（jxb_id），与成绩的 `id` 对应
    public var classId: String
    public var courseId: String
    public var courseName: String
    /// 学时类型（xsmc）：理论 / 实验 / 实践 / 实习
    public var type: String
    /// 开课类型（kklxmc），如"通识选修课"
    public var selectionType: String
    public var classification: String
    public var belongTo: String
    /// 课程体系 / 模块（kcxzmc），如"艺术与审美""创业"
    public var system: String
    public var teacher: String
    public var teacherId: String
    public var credit: Double
    public var year: Int
    /// 1 秋 / 2 春 / 3 小学期（历年记录里有 3，所以缓存和展示都要接受）
    public var term: Int
    /// 上课教室，多个用 `;` 分隔，可能为空
    public var location: String

    public var id: String { "\(year)-\(term)-\(classId)" }

    /// 网课：开课归属含"网络"，或教师名是"网络教师"（RN 口径）。教师工号 `000000` 是网络课程的占位工号，
    /// 真实数据里与"网络教师"完全对应（7 门）；脱敏数据里教师名被替换了，工号保留，所以一并判断
    public var isOnline: Bool { belongTo.contains("网络") || teacher == "网络教师" || teacherId == "000000" }
    /// 实验类课程（用于"未出分科目"加"(实验)"）：学时类型是"实验"
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

    /// 超出 Int 范围的数字直接转 Int 会崩溃，当作缺失（0），后面 `rows()` 会以"学年学期无效"拒绝
    func lenientInt(_ key: Key) -> Int? {
        guard let v = lenientNumber(key), abs(v) < 1e15 else { return nil }
        return Int(v)
    }

    func lenientNumber(_ key: Key) -> Double? {
        if let v = try? decodeIfPresent(Double.self, forKey: key), v.isFinite { return v }
        if let v = try? decodeIfPresent(String.self, forKey: key), let d = Double(v.trimmingCharacters(in: .whitespaces)), d.isFinite { return d }   // "NaN" / "inf" 当缺失（RN：Number(x) || 0）
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

    /// 全部历史或指定学期。`data` 为 null 视为空列表
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

/// 已选课程的本地缓存，按 studentId 隔离
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
        // 真实响应有 location 字段（上课教室）
        migrator.registerMigration("course.v2.addSelectedCourseLocation") { db in
            try db.alter(table: "selected_course") { t in
                t.add(column: "location", .text).notNull().defaults(to: "")
            }
        }
    }

    /// 学年、学期降序，同学期按课程名
    public func list(studentId: String, scope: SelectedCourseScope) async throws -> [SelectedCourse] {
        try await database.writer.read { db in
            var request = SelectedCourseRecord.filter(Column("studentId") == studentId)
            if case .term(let t) = scope { request = request.filter(Column("year") == t.year && Column("term") == t.term) }
            return try request.order(Column("year").desc, Column("term").desc, Column("courseName")).fetchAll(db).map(Self.course)
        }
    }

    /// 全量刷新：只替换本账号的全部记录
    public func replaceAll(_ items: [SelectedCourse], studentId: String, now: Date = .now) async throws {
        let rows = try Self.rows(items, studentId: studentId, now: now)
        try await database.writer.write { db in
            try SelectedCourseRecord.filter(Column("studentId") == studentId).deleteAll(db)
            for row in rows { try row.save(db) }
        }
    }

    /// 学期刷新：只替换本账号该学期；响应里混进别的学期时报错，不写入
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
        // 同一学期同一教学班出现多次时留最后一条（RN 的 Map 也是后写覆盖先写），位置保持第一次出现的位置
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
