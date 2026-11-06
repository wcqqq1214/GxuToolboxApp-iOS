import Foundation
import GxuFoundation
import GxuStorage

struct ExamInfoRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "exam_info"
    var studentId: String
    var id: String
    var year: Int
    var term: Int
    var course: String
    var classroom: String
    var time: String
    var type: String
    var seat: String
    var updatedAt: Date
}

struct ScoreRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "score"
    var studentId: String
    var id: String
    var year: Int
    var term: Int
    var courseName: String
    var credit: Double?
    var score: Double?
    var teacherName: String
    var uploadAt: String
    var usualScoreJSON: String?
    var updatedAt: Date
}

/// 考试信息与成绩的本地缓存。每个方法都带 `studentId`，账号之间互相不可见。
public struct ExamRepository: Sendable {
    let database: AppDatabase

    public init(database: AppDatabase) { self.database = database }

    public static let migrations = FeatureMigrations(feature: "exam") { migrator in
        migrator.registerMigration("exam.v1.createExamInfo") { db in
            try db.create(table: "exam_info") { t in
                t.column("studentId", .text).notNull()
                t.column("id", .text).notNull()
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("course", .text).notNull()
                t.column("classroom", .text).notNull()
                t.column("time", .text).notNull()
                t.column("type", .text).notNull()
                t.column("seat", .text).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.primaryKey(["studentId", "year", "term", "id"])
            }
        }
        migrator.registerMigration("exam.v1.createScore") { db in
            try db.create(table: "score") { t in
                t.column("studentId", .text).notNull()
                t.column("id", .text).notNull()
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("courseName", .text).notNull()
                t.column("credit", .double)
                t.column("score", .double)
                t.column("teacherName", .text).notNull()
                t.column("uploadAt", .text).notNull()
                t.column("usualScoreJSON", .text)
                t.column("updatedAt", .datetime).notNull()
                t.primaryKey(["studentId", "id"])
            }
            try db.create(index: "score_slice", on: "score", columns: ["studentId", "year", "term"])
        }
    }

    // MARK: 考试信息

    public func exams(studentId: String, term: AcademicTerm) async throws -> [Exam] {
        try await database.writer.read { db in
            try ExamInfoRecord
                .filter(Column("studentId") == studentId && Column("year") == term.year && Column("term") == term.term)
                .order(Column("time"))
                .fetchAll(db)
                .map { Exam(id: $0.id, course: $0.course, classroom: $0.classroom, time: $0.time, type: $0.type, seat: $0.seat) }
        }
    }

    /// 事务内先删该学期切片再插入新数据，保证已取消的考试不残留
    public func replaceExams(_ exams: [Exam], studentId: String, term: AcademicTerm, now: Date = .now) async throws {
        try await database.writer.write { db in
            try ExamInfoRecord
                .filter(Column("studentId") == studentId && Column("year") == term.year && Column("term") == term.term)
                .deleteAll(db)
            for e in exams {
                try ExamInfoRecord(
                    studentId: studentId, id: e.id, year: term.year, term: term.term, course: e.course,
                    classroom: e.classroom, time: e.time, type: e.type, seat: e.seat, updatedAt: now
                ).save(db)
            }
        }
    }

    // MARK: 成绩

    /// `term == nil` 表示该学年的全部学期。按发布时间降序
    public func scores(studentId: String, year: Int, term: Int?) async throws -> [Score] {
        try await database.writer.read { db in
            var request = ScoreRecord.filter(Column("studentId") == studentId && Column("year") == year)
            if let term { request = request.filter(Column("term") == term) }
            return try request.order(Column("uploadAt").desc).fetchAll(db).map(Self.score)
        }
    }

    public func lastSyncedAt(studentId: String, year: Int, term: Int?) async throws -> Date? {
        try await database.writer.read { db in
            var request = ScoreRecord.filter(Column("studentId") == studentId && Column("year") == year)
            if let term { request = request.filter(Column("term") == term) }
            return try request.select(max(Column("updatedAt")), as: Date?.self).fetchOne(db) ?? nil
        }
    }

    /// 事务内按 id upsert（保留已缓存的平时分），并删除该学期切片里不在本次响应中的行
    public func replaceScores(_ scores: [Score], studentId: String, year: Int, term: Int, now: Date = .now) async throws {
        try await database.writer.write { db in
            let keep = Set(scores.map(\.id))
            let stale = try ScoreRecord
                .filter(Column("studentId") == studentId && Column("year") == year && Column("term") == term)
                .fetchAll(db)
                .filter { !keep.contains($0.id) }
            for row in stale {
                try ScoreRecord.filter(Column("studentId") == studentId && Column("id") == row.id).deleteAll(db)
            }
            for s in scores {
                let existing = try ScoreRecord.filter(Column("studentId") == studentId && Column("id") == s.id).fetchOne(db)
                try ScoreRecord(
                    studentId: studentId, id: s.id, year: s.year, term: s.term, courseName: s.courseName,
                    credit: s.credit, score: s.score, teacherName: s.teacherName, uploadAt: s.uploadAt,
                    usualScoreJSON: existing?.usualScoreJSON, updatedAt: now
                ).save(db)
            }
        }
    }

    /// 本账号全部已缓存成绩（所有学年学期）
    public func allScores(studentId: String) async throws -> [Score] {
        try await database.writer.read { db in
            try ScoreRecord.filter(Column("studentId") == studentId).order(Column("uploadAt").desc).fetchAll(db).map(Self.score)
        }
    }

    public func allLastSyncedAt(studentId: String) async throws -> Date? {
        try await database.writer.read { db in
            try ScoreRecord.filter(Column("studentId") == studentId).select(max(Column("updatedAt")), as: Date?.self).fetchOne(db) ?? nil
        }
    }

    /// 全部历史刷新：按 (year, term) 切片分别替换（每个切片内同样删除不在响应里的行）。
    /// 响应里完全没出现的学期不动。
    public func replaceAllScores(_ scores: [Score], studentId: String, now: Date = .now) async throws {
        let groups = Dictionary(grouping: scores) { "\($0.year)#\($0.term)" }
        for (_, items) in groups {
            guard let first = items.first else { continue }
            try await replaceScores(items, studentId: studentId, year: first.year, term: first.term, now: now)
        }
    }

    public func usualScores(studentId: String, scoreId: String) async throws -> [UsualScoreItem]? {
        let json = try await database.writer.read { db in
            try ScoreRecord.filter(Column("studentId") == studentId && Column("id") == scoreId).fetchOne(db)?.usualScoreJSON
        }
        guard let json, let items = try? JSONDecoder().decode([UsualScoreItem].self, from: Data(json.utf8)), !items.isEmpty
        else { return nil }
        return items
    }

    /// 空数组不缓存，下次展开会重新请求
    public func saveUsualScores(_ items: [UsualScoreItem], studentId: String, scoreId: String) async throws {
        guard !items.isEmpty else { return }
        let json = String(decoding: try JSONEncoder().encode(items), as: UTF8.self)
        try await database.writer.write { db in
            _ = try ScoreRecord
                .filter(Column("studentId") == studentId && Column("id") == scoreId)
                .updateAll(db, Column("usualScoreJSON").set(to: json))
        }
    }

    private static func score(_ r: ScoreRecord) -> Score {
        Score(id: r.id, year: r.year, term: r.term, courseName: r.courseName, credit: r.credit,
              score: r.score, teacherName: r.teacherName, uploadAt: r.uploadAt)
    }
}

// MARK: 下一场考试

extension ExamRepository {
    /// 本账号所有已缓存学期里的考试，状态按 `now` 重新计算
    public func allExams(studentId: String, now: Date = .now, calendar: Calendar = .current) async throws -> [ExamItem] {
        try await database.writer.read { db in
            try ExamInfoRecord.filter(Column("studentId") == studentId).fetchAll(db)
                .map { Exam(id: $0.id, course: $0.course, classroom: $0.classroom, time: $0.time, type: $0.type, seat: $0.seat) }
        }
        .map { ExamItem($0, now: now, calendar: calendar) }
    }

    /// 最近的一场未结束的考试（只读本地缓存，不联网，适合小组件和 App Intent）。
    /// 正在进行的考试（结束时间不早于 now）也算；时间未知的考试不参与。
    public func nextExam(studentId: String, now: Date = .now, calendar: Calendar = .current) async throws -> ExamItem? {
        NextExam.pick(from: try await allExams(studentId: studentId, now: now, calendar: calendar))
    }

    /// 最近 `limit` 场未结束的考试，按开考时间升序
    public func upcomingExams(studentId: String, limit: Int = 3, now: Date = .now, calendar: Calendar = .current) async throws -> [ExamItem] {
        Array(NextExam.upcoming(in: try await allExams(studentId: studentId, now: now, calendar: calendar)).prefix(limit))
    }
}
