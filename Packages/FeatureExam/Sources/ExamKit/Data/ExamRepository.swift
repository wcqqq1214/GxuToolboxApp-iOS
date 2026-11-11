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


    public func exams(studentId: String, term: AcademicTerm) async throws -> [Exam] {
        try await database.writer.read { db in
            try ExamInfoRecord
                .filter(Column("studentId") == studentId && Column("year") == term.year && Column("term") == term.term)
                .order(Column("time"))
                .fetchAll(db)
                .map { Exam(id: $0.id, course: $0.course, classroom: $0.classroom, time: $0.time, type: $0.type, seat: $0.seat) }
        }
    }

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


extension ExamRepository {
    public func allExams(studentId: String, now: Date = .now, calendar: Calendar = .current) async throws -> [ExamItem] {
        try await database.writer.read { db in
            try ExamInfoRecord.filter(Column("studentId") == studentId).fetchAll(db)
                .map { Exam(id: $0.id, course: $0.course, classroom: $0.classroom, time: $0.time, type: $0.type, seat: $0.seat) }
        }
        .map { ExamItem($0, now: now, calendar: calendar) }
    }

    public func nextExam(studentId: String, now: Date = .now, calendar: Calendar = .current) async throws -> ExamItem? {
        NextExam.pick(from: try await allExams(studentId: studentId, now: now, calendar: calendar))
    }

    public func upcomingExams(studentId: String, limit: Int = 3, now: Date = .now, calendar: Calendar = .current) async throws -> [ExamItem] {
        Array(NextExam.upcoming(in: try await allExams(studentId: studentId, now: now, calendar: calendar)).prefix(limit))
    }
}
