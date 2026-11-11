import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage

public struct EngTrainingDay: Codable, Sendable, Hashable, Identifiable {
    public var dateText: String
    public var date: Date
    public var name: String
    public var id: String { dateText }
}

public enum EngTrainingParser {
    private struct Cell {
        let startRow: Int, startCol: Int, colNumber: Int
        let content: String
    }

    public static func parse(_ data: Data, now: Date = .now, calendar: Calendar = .current) throws -> [EngTrainingDay] {
        try parseTable(data, now: now, calendar: calendar).days
    }

    public static func parseTable(_ data: Data, now: Date = .now, calendar: Calendar = .current) throws -> (cellCount: Int, days: [EngTrainingDay]) {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tables = root["datas"] as? [Any], let first = tables.first as? [[String: Any]]
        else { throw GxuError.decoding("金工实训数据格式不正确") }
        let cells = first.compactMap { raw -> Cell? in
            func int(_ key: String) -> Int? { (raw[key] as? Int) ?? (raw[key] as? String).flatMap(Int.init) }
            guard let row = int("startRow"), let col = int("startCol") else { return nil }
            return Cell(startRow: row, startCol: col, colNumber: max(int("colNumber") ?? 1, 1), content: (raw["content"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let dates = cells.filter { $0.startRow == 2 }
        var seen = Set<String>()
        let days = dates.compactMap { date -> EngTrainingDay? in
            guard let day = resolve(date.content, now: now, calendar: calendar), seen.insert(date.content).inserted else { return nil }
            let exp = cells.first {
                $0.startRow == 9 && $0.startCol <= date.startCol && $0.startCol + $0.colNumber >= date.startCol + date.colNumber
            }
            return EngTrainingDay(dateText: date.content, date: day, name: exp?.content ?? "")
        }
        .sorted { $0.date < $1.date }
        return (cells.count, days)
    }

    static func resolve(_ text: String, now: Date, calendar: Calendar) -> Date? {
        let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard numbers.count >= 2 else { return nil }
        let calendar = calendar.gregorianEquivalent
        let year = calendar.component(.year, from: now)
        let candidates = [year - 1, year, year + 1].compactMap { candidate -> Date? in
            guard let date = calendar.date(from: DateComponents(year: candidate, month: numbers[0], day: numbers[1])) else { return nil }
            let back = calendar.dateComponents([.month, .day], from: date)
            return back.month == numbers[0] && back.day == numbers[1] ? date : nil
        }
        return candidates.min { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) }
    }
}

public protocol EngTrainingClient: Sendable {
    func scheduleTable() async throws -> Data
}

public struct LiveEngTrainingClient: EngTrainingClient {
    let unified: UnifiedAuthSession?

    let username: String

    public init(unified: UnifiedAuthSession?, username: String) {
        self.unified = unified
        self.username = username
    }

    public func scheduleTable() async throws -> Data {
        guard let unified else { throw GxuError.notLoggedIn(.unified) }
        let request = URLRequest(url: URL(string: "http://xlzxms.gxu.edu.cn/api/course-newedition-server/course/course/arrange/stuPersonalArrangeTable")!)
        let (data, response) = try await unified.engTrainingData(for: request, username: username)
        guard (200..<300).contains(response.statusCode) else { throw GxuError.http(status: response.statusCode, message: nil) }
        return data
    }
}

public struct EngTrainingRepository: Sendable {
    private let database: AppDatabase
    private let client: any EngTrainingClient

    public init(database: AppDatabase, client: any EngTrainingClient) {
        self.database = database
        self.client = client
    }

    public func cached(unifiedUsername: String) async -> [EngTrainingDay] {
        let cacheKey = PracticeCache.key(for: unifiedUsername)
        let blobs = try? await database.writer.read { db -> [Data] in
            try Row.fetchAll(db, sql: "SELECT json FROM eng_training WHERE studentId = ?", arguments: [cacheKey]).map { $0["json"] }
        }
        return (blobs ?? []).compactMap { try? JSONDecoder().decode(EngTrainingDay.self, from: $0) }.sorted { $0.date < $1.date }
    }

    @discardableResult
    public func refresh(unifiedUsername: String, now: Date = .now) async throws -> [EngTrainingDay] {
        let table = try EngTrainingParser.parseTable(try await client.scheduleTable(), now: now)
        if table.cellCount > 0, table.days.isEmpty { throw GxuError.decoding("金工实训数据格式不正确") }
        let days = table.days
        let cacheKey = PracticeCache.key(for: unifiedUsername)
        let rows = try days.map { ($0.dateText, try JSONEncoder().encode($0)) }
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM eng_training WHERE studentId = ?", arguments: [cacheKey])
            for (id, json) in rows {
                try db.execute(sql: "INSERT INTO eng_training (studentId, id, json) VALUES (?, ?, ?)", arguments: [cacheKey, id, json])
            }
        }
        return days
    }
}
