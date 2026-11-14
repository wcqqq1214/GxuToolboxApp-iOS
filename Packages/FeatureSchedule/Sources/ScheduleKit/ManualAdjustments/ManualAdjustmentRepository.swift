import Foundation
import GxuFoundation
import GxuStorage

extension ScheduleRepository {
    public func manualCourseAdjustments(studentId: String, term: AcademicTerm) async -> [ManualCourseAdjustment] {
        let records = await ErrorLog.shared.attempt("cache", "读取本地调课失败") {
            try await database.writer.read { db in
                try Row.fetchAll(db, sql: "SELECT json FROM schedule_manual_adjustment WHERE studentId = ? AND year = ? AND term = ? ORDER BY id",
                                 arguments: [studentId, term.year, term.term]).map { row -> Data in row["json"] }
            }
        }
        return (records ?? []).compactMap { data in
            ErrorLog.shared.attempt("cache", "解码本地调课失败") { try JSONDecoder().decode(ManualCourseAdjustment.self, from: data) }
        }
    }

    public func saveManualCourseAdjustments(_ adjustments: [ManualCourseAdjustment], studentId: String, term: AcademicTerm) async throws {
        if let message = adjustments.compactMap(\.validationMessage).first { throw GxuError.invalidData(message) }
        let records = try adjustments.map { ($0.id, try JSONEncoder().encode($0)) }
        try await database.writer.write { db in
            for (id, data) in records {
                try db.execute(sql: """
                    INSERT INTO schedule_manual_adjustment (studentId, year, term, id, json) VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(studentId, year, term, id) DO UPDATE SET json = excluded.json
                    """, arguments: [studentId, term.year, term.term, id, data])
            }
        }
    }

    public func deleteManualCourseAdjustment(id: String, studentId: String, term: AcademicTerm) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM schedule_manual_adjustment WHERE studentId = ? AND year = ? AND term = ? AND id = ?",
                           arguments: [studentId, term.year, term.term, id])
        }
    }
}
