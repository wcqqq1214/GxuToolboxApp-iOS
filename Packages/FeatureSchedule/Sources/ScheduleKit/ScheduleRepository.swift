import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage

public struct CachedSchedule: Sendable, Equatable {
    public var schedule: Schedule
    public var updatedAt: Date
}

public struct ScheduleRepository: Sendable {
    private let backend: any BackendAPI
    let database: AppDatabase

    public init(backend: any BackendAPI, database: AppDatabase) {
        self.backend = backend
        self.database = database
    }


    public func cachedSchedule(studentId: String, term: AcademicTerm) async throws -> CachedSchedule? {
        try await database.writer.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT json, updatedAt FROM schedule_snapshot WHERE studentId = ? AND year = ? AND term = ?",
                arguments: [studentId, term.year, term.term]
            ) else { return nil }
            let data: Data = row["json"]
            guard let schedule = try? JSONDecoder().decode(Schedule.self, from: data) else { return nil }
            return CachedSchedule(schedule: schedule, updatedAt: Date(timeIntervalSince1970: row["updatedAt"]))
        }
    }

    @discardableResult
    public func refreshSchedule(studentId: String, term: AcademicTerm, now: Date = .now) async throws -> CachedSchedule {
        let remote = try await backend.getData(
            "/jw/schedule/personal",
            query: ["year": String(term.year), "term": String(term.term)],
            auth: .jw,
            as: Schedule?.self
        )
        guard let schedule = remote else { throw GxuError.invalidData("课表数据暂时无法解析，请稍后重试") }
        let data = try JSONEncoder().encode(schedule)
        try await database.writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO schedule_snapshot (studentId, year, term, json, updatedAt) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(studentId, year, term) DO UPDATE SET json = excluded.json, updatedAt = excluded.updatedAt
                """,
                arguments: [studentId, term.year, term.term, data, now.timeIntervalSince1970]
            )
        }
        return CachedSchedule(schedule: schedule, updatedAt: now)
    }


    public func cachedStartDays() async throws -> [TermStartDay] {
        try await database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT year, term, day, week FROM term_start_day ORDER BY year, term").map {
                TermStartDay(year: $0["year"], term: $0["term"], day: $0["day"], week: $0["week"])
            }
        }
    }

    @discardableResult
    public func refreshStartDays() async throws -> [TermStartDay] {
        let terms = try await backend.getData("/jw/profile/startDay", auth: .jw, as: [TermStartDay].self)
            .filter { (1...TermCalendar.maximumWeeks).contains($0.week) }
        guard !terms.isEmpty else { return try await cachedStartDays() }
        try await database.writer.write { db in
            for term in terms {
                try db.execute(
                    sql: """
                    INSERT INTO term_start_day (year, term, day, week) VALUES (?, ?, ?, ?)
                    ON CONFLICT(year, term) DO UPDATE SET day = excluded.day, week = excluded.week
                    """,
                    arguments: [term.year, term.term, term.day, term.week]
                )
            }
        }
        return terms
    }


    public func currentTermInfo(now: Date = .now, calendar: Calendar = .current) async -> CurrentTermInfo? {
        var terms = (try? await cachedStartDays()) ?? []
        let cachedCurrent = TermResolver.current(in: terms, now: now, calendar: calendar)
        let needsRefresh = cachedCurrent.flatMap { TermCalendar($0, calendar: calendar) }.map { $0.isEnded(at: now) } ?? true
        if needsRefresh, let refreshed = try? await refreshStartDays() { terms = refreshed }
        guard
            let current = TermResolver.current(in: terms, now: now, calendar: calendar),
            let termCalendar = TermCalendar(current, calendar: calendar)
        else { return nil }
        return CurrentTermInfo(
            term: current.academicTerm,
            isStarted: termCalendar.isStarted(at: now),
            isEnded: termCalendar.isEnded(at: now),
            calendar: termCalendar
        )
    }
}

public struct CurrentTermInfo: Sendable, Equatable {
    public var term: AcademicTerm
    public var isStarted: Bool
    public var isEnded: Bool
    public var calendar: TermCalendar
}
