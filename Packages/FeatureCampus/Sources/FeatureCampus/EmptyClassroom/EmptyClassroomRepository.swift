import Foundation
import GxuFoundation
import GxuStorage

public struct AvailableRoomsPage: Sendable {
    public var rows: [AvailableRoomPeriodRow]
    public var hasMore: Bool
    public var totalCount: Int
}

public struct AvailableRoomsQuery: Sendable {
    public var year: Int
    public var term: Int
    public var week: Int
    public var day: Int
    public var startPeriod: Int
    public var endPeriod: Int
    public var buildings: [String] = []
    public var roomIds: [Int64] = []
    public var keyword: String = ""
    public var page: Int = 1
    public var pageSize: Int = EmptyClassroomConstants.availableRoomPageSize
    public var sortMode: TimeQuerySortMode = .default
    public var sortDirection: TimeQuerySortDirection = .desc
    public var includeTotal = true

    public init(year: Int, term: Int, week: Int, day: Int, startPeriod: Int, endPeriod: Int) {
        self.year = year; self.term = term; self.week = week; self.day = day
        self.startPeriod = startPeriod; self.endPeriod = endPeriod
    }
}

public struct EmptyClassroomRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) { self.database = database }


    public func saveDay(year: Int, term: Int, week: Int, day: Int, payload: DayPayload, now: Date = .now) async throws {
        try await database.writer.write { db in
            for room in payload.rooms.values {
                try db.execute(
                    sql: """
                    INSERT INTO empty_room (building, name, placeType, seatCount, seatCountForExam, owner, allowToUse, updatedAt)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(building, name) DO NOTHING
                    """,
                    arguments: [room.building, room.name, room.placeType, room.seatCount, room.seatCountForExam, room.owner, room.allowToUse, now.timeIntervalSince1970]
                )
            }
            var ids: [String: Int64] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT id, building, name FROM empty_room") {
                ids[emptyRoomKey(row["building"], row["name"])] = row["id"]
            }
            try db.execute(sql: "DELETE FROM empty_slot WHERE year = ? AND term = ? AND week = ? AND day = ?", arguments: [year, term, week, day])
            var slotCount = 0
            for (key, periods) in payload.freePeriods {
                guard let roomId = ids[key] else { continue }
                for period in Set(periods) {
                    try db.execute(
                        sql: "INSERT OR IGNORE INTO empty_slot (year, term, week, day, period, roomId) VALUES (?, ?, ?, ?, ?, ?)",
                        arguments: [year, term, week, day, period, roomId]
                    )
                }
                slotCount += periods.count
            }
            try db.execute(
                sql: """
                INSERT INTO empty_day (year, term, week, day, fetchedAt, slotCount) VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(year, term, week, day) DO UPDATE SET fetchedAt = excluded.fetchedAt, slotCount = excluded.slotCount
                """,
                arguments: [year, term, week, day, now.timeIntervalSince1970, slotCount]
            )
            try Self.upsertSnapshot(db, year: year, term: term, week: week, fetchedAt: now)
        }
    }

    public func completeWeek(year: Int, term: Int, week: Int, now: Date = .now) async throws {
        try await database.writer.write { db in try Self.upsertSnapshot(db, year: year, term: term, week: week, fetchedAt: now) }
    }

    public func deleteWeek(year: Int, term: Int, week: Int) async throws {
        try await database.writer.write { db in
            let args: StatementArguments = [year, term, week]
            try db.execute(sql: "DELETE FROM empty_slot WHERE year = ? AND term = ? AND week = ?", arguments: args)
            try db.execute(sql: "DELETE FROM empty_day WHERE year = ? AND term = ? AND week = ?", arguments: args)
            try db.execute(sql: "DELETE FROM empty_snapshot WHERE year = ? AND term = ? AND week = ?", arguments: args)
        }
    }

    public func clearWeeks() async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM empty_slot")
            try db.execute(sql: "DELETE FROM empty_day")
            try db.execute(sql: "DELETE FROM empty_snapshot")
        }
    }

    public func clearAll() async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM empty_slot")
            try db.execute(sql: "DELETE FROM empty_day")
            try db.execute(sql: "DELETE FROM empty_snapshot")
            try db.execute(sql: "DELETE FROM empty_room")
        }
    }

    private static func upsertSnapshot(_ db: Database, year: Int, term: Int, week: Int, fetchedAt: Date) throws {
        let days = try Row.fetchAll(db, sql: "SELECT slotCount FROM empty_day WHERE year = ? AND term = ? AND week = ?", arguments: [year, term, week])
        let completedDays = days.count
        let slotCount = days.reduce(0) { $0 + ($1["slotCount"] as Int) }
        let complete = completedDays == EmptyClassroomConstants.days
        var roomCount = 0
        if complete {
            roomCount = try Int.fetchOne(
                db, sql: "SELECT COUNT(DISTINCT roomId) FROM empty_slot WHERE year = ? AND term = ? AND week = ?", arguments: [year, term, week]
            ) ?? 0
        }
        try db.execute(
            sql: """
            INSERT INTO empty_snapshot (year, term, week, fetchedAt, completedDays, slotCount, roomCount, complete)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(year, term, week) DO UPDATE SET
                fetchedAt = excluded.fetchedAt, completedDays = excluded.completedDays, slotCount = excluded.slotCount,
                roomCount = excluded.roomCount, complete = excluded.complete
            """,
            arguments: [year, term, week, fetchedAt.timeIntervalSince1970, completedDays, slotCount, roomCount, complete ? 1 : 0]
        )
    }


    public func completedDays(year: Int, term: Int, week: Int) async throws -> [Int] {
        try await database.writer.read { db in
            try Int.fetchAll(db, sql: "SELECT day FROM empty_day WHERE year = ? AND term = ? AND week = ? ORDER BY day", arguments: [year, term, week])
        }
    }

    public func week(year: Int, term: Int, week: Int) async throws -> WeekSnapshot? {
        try await database.writer.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM empty_snapshot WHERE year = ? AND term = ? AND week = ?", arguments: [year, term, week])
                .map(Self.snapshot).flatMap { $0.completedDays > 0 ? $0 : nil }
        }
    }

    public func listWeeks(year: Int, term: Int) async throws -> [WeekSnapshot] {
        try await database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM empty_snapshot WHERE year = ? AND term = ? ORDER BY week", arguments: [year, term])
                .map(Self.snapshot).filter { $0.completedDays > 0 }
        }
    }

    public func storageUsage() async throws -> (roomsBytes: Int, availabilityBytes: Int) {
        try await database.writer.read { db in
            let rooms = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM empty_room") ?? 0
            let slots = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(slotCount), 0) FROM empty_snapshot") ?? 0
            return (EmptyClassroomLogic.estimatedBytes(slots: 0, rooms: rooms), EmptyClassroomLogic.estimatedBytes(slots: slots, rooms: 0))
        }
    }

    public func listRoomBuildings() async throws -> [RoomBuildingSummary] {
        try await database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT building, COUNT(*) AS roomCount FROM empty_room GROUP BY building")
                .map { RoomBuildingSummary(building: $0["building"], roomCount: $0["roomCount"]) }
        }
    }

    public func listRooms(inBuilding building: String) async throws -> [RoomRecord] {
        try await database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM empty_room WHERE building = ? ORDER BY name", arguments: [building]).map(Self.room)
        }
    }

    public func room(id: Int64) async throws -> RoomRecord? {
        try await database.writer.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM empty_room WHERE id = ?", arguments: [id]).map(Self.room)
        }
    }

    public func searchRooms(keyword: String, building: String? = nil) async throws -> [RoomRecord] {
        let text = keyword.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return [] }
        return try await database.writer.read { db in
            var sql = "SELECT * FROM empty_room WHERE (name LIKE ? ESCAPE '\\' OR placeType LIKE ? ESCAPE '\\')"
            var args: [any DatabaseValueConvertible] = [Self.likePattern(text), Self.likePattern(text)]
            if let building { sql += " AND building = ?"; args.append(building) }
            sql += " ORDER BY building, name"
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args)).map(Self.room)
        }
    }

    public func roomWeekSlots(year: Int, term: Int, roomId: Int64, weeks: [Int]) async throws -> [FreePeriodRow] {
        guard !weeks.isEmpty else { return [] }
        return try await database.writer.read { db in
            let marks = weeks.map { _ in "?" }.joined(separator: ",")
            var args: [any DatabaseValueConvertible] = [year, term, roomId]
            args += weeks
            return try Row.fetchAll(
                db, sql: "SELECT week, day, period FROM empty_slot WHERE year = ? AND term = ? AND roomId = ? AND week IN (\(marks)) ORDER BY week, day, period",
                arguments: StatementArguments(args)
            ).map { FreePeriodRow(week: $0["week"], day: $0["day"], period: $0["period"]) }
        }
    }

    public func listAvailableRooms(_ q: AvailableRoomsQuery) async throws -> AvailableRoomsPage {
        try await database.writer.read { db in
            let page = max(1, q.page), pageSize = max(1, q.pageSize)
            var conditions = ["s.year = ?", "s.term = ?", "s.week = ?", "s.day = ?", "s.period >= ?", "s.period <= ?"]
            var args: [any DatabaseValueConvertible] = [q.year, q.term, q.week, q.day, q.startPeriod, q.endPeriod]
            if !q.buildings.isEmpty {
                conditions.append("r.building IN (\(q.buildings.map { _ in "?" }.joined(separator: ",")))")
                args += q.buildings
            }
            if !q.roomIds.isEmpty {
                conditions.append("r.id IN (\(q.roomIds.map { _ in "?" }.joined(separator: ",")))")
                args += q.roomIds
            }
            let keyword = q.keyword.trimmingCharacters(in: .whitespaces)
            if !keyword.isEmpty {
                conditions.append("(r.name LIKE ? ESCAPE '\\' OR r.placeType LIKE ? ESCAPE '\\')")
                args += [Self.likePattern(keyword), Self.likePattern(keyword)]
            }
            let filter = conditions.joined(separator: " AND ")
            let from = "FROM empty_slot s JOIN empty_room r ON s.roomId = r.id"

            var total = 0
            if q.includeTotal {
                total = try Int.fetchOne(db, sql: "SELECT COUNT(DISTINCT r.id) \(from) WHERE \(filter)", arguments: StatementArguments(args)) ?? 0
            }
            let order: String
            if q.sortMode == .free {
                order = "COUNT(s.period) \(q.sortDirection == .asc ? "ASC" : "DESC"), MIN(s.period) ASC, r.building ASC, r.name ASC, r.id ASC"
            } else {
                order = "r.building ASC, r.name ASC, r.id ASC"
            }
            let candidates = try Int64.fetchAll(
                db, sql: "SELECT r.id \(from) WHERE \(filter) GROUP BY r.id ORDER BY \(order) LIMIT ? OFFSET ?",
                arguments: StatementArguments(args + [pageSize + 1, (page - 1) * pageSize])
            )
            let hasMore = candidates.count > pageSize
            let pageIds = Array(candidates.prefix(pageSize))
            guard !pageIds.isEmpty else { return AvailableRoomsPage(rows: [], hasMore: false, totalCount: total) }
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT r.*, s.period AS slotPeriod \(from)
                WHERE \(filter) AND r.id IN (\(pageIds.map { _ in "?" }.joined(separator: ",")))
                ORDER BY r.building ASC, r.name ASC, s.period ASC
                """,
                arguments: StatementArguments(args + pageIds.map { $0 as any DatabaseValueConvertible })
            )
            return AvailableRoomsPage(
                rows: rows.map { AvailableRoomPeriodRow(room: Self.room($0), week: q.week, day: q.day, period: $0["slotPeriod"]) },
                hasMore: hasMore, totalCount: total
            )
        }
    }


    private static func room(_ row: Row) -> RoomRecord {
        RoomRecord(
            id: row["id"], building: row["building"], name: row["name"], placeType: row["placeType"] ?? "",
            seatCount: row["seatCount"], seatCountForExam: row["seatCountForExam"], owner: row["owner"] ?? "", allowToUse: row["allowToUse"] ?? ""
        )
    }

    private static func snapshot(_ row: Row) -> WeekSnapshot {
        WeekSnapshot(
            year: row["year"], term: row["term"], week: row["week"], fetchedAt: Date(timeIntervalSince1970: row["fetchedAt"]),
            completedDays: row["completedDays"], slotCount: row["slotCount"], roomCount: row["roomCount"], complete: (row["complete"] as Int) != 0
        )
    }

    static func likePattern(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }
}
