import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage
import ScheduleKit

public struct PhyExperiment: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var week: String
    public var className: String
    public var dateText: String
    public var timeText: String
    public var courseName: String
    public var experimentName: String
    public var teacher: String
    public var location: String
    public var labName: String

    public func date(calendar: Calendar = .current) -> Date? {
        guard dateText.count == 8, let year = Int(dateText.prefix(4)), let month = Int(dateText.dropFirst(4).prefix(2)), let day = Int(dateText.suffix(2))
        else { return nil }
        let calendar = calendar.gregorianEquivalent
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let actual = calendar.dateComponents([.year, .month, .day], from: date)
        return actual.year == year && actual.month == month && actual.day == day ? date : nil
    }

    public var title: String { experimentName.isEmpty ? courseName : experimentName }
    public var place: String { location.isEmpty ? labName : location }
}

public enum PhyExpParser {
    public static func parse(_ data: Data) throws -> [PhyExperiment] { try parseRows(data).items }

    public static func parseRows(_ data: Data) throws -> (rowCount: Int, items: [PhyExperiment]) {
        guard let outer = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GxuError.decoding("物理实验数据格式不正确")
        }
        let inner: Any
        if let text = outer["d"] as? String, let innerData = text.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: innerData) {
            inner = parsed
        } else if let object = outer["d"] {
            inner = object
        } else {
            inner = outer
        }
        let rows: [[String: Any]]
        if let object = inner as? [String: Any], let list = object["data"] as? [[String: Any]] {
            rows = list
        } else if let list = inner as? [[String: Any]] {
            rows = list
        } else {
            throw GxuError.decoding("物理实验数据格式不正确")
        }
        return (rows.count, rows.compactMap(experiment(from:)))
    }

    private static func experiment(from row: [String: Any]) -> PhyExperiment? {
        let lowered = Dictionary(row.map { ($0.key.lowercased(), $0.value is NSNull ? "" : "\($0.value)") }, uniquingKeysWith: { first, _ in first })
        func value(_ key: String) -> String { (lowered[key] ?? "").trimmingCharacters(in: .whitespaces) }
        let date = value("skrq")
        guard !date.isEmpty else { return nil }
        return PhyExperiment(
            id: value("id").isEmpty ? "\(date)-\(value("sksj"))-\(value("xmmc"))" : value("id"),
            week: value("zc"), className: value("bjmc"), dateText: date, timeText: value("sksj"),
            courseName: value("kcmc"), experimentName: value("xmmc"),
            teacher: value("zjjsxm"), location: value("fjbh"), labName: value("sysmc")
        )
    }
}

public protocol PECClient: Sendable {
    func ruleManage() async throws -> Data
}

public struct LivePECClient: PECClient {
    let unified: UnifiedAuthSession?

    let username: String

    public init(unified: UnifiedAuthSession?, username: String) {
        self.unified = unified
        self.username = username
    }

    public func ruleManage() async throws -> Data {
        guard let unified else { throw GxuError.notLoggedIn(.unified) }
        var request = URLRequest(url: URL(string: "https://pec.gxu.edu.cn/LMSmini/teacher/UI/wxInterface/syjx.asmx/getRuleManage")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["page": 1, "limit": 100])
        let (data, response) = try await unified.pecData(for: request, username: username)
        guard (200..<300).contains(response.statusCode) else { throw GxuError.http(status: response.statusCode, message: nil) }
        return data
    }
}

public struct PhyExpRepository: Sendable {
    private let database: AppDatabase
    private let client: any PECClient

    public init(database: AppDatabase, client: any PECClient) {
        self.database = database
        self.client = client
    }

    public func cached(unifiedUsername: String) async -> [PhyExperiment] {
        let cacheKey = PracticeCache.key(for: unifiedUsername)
        let blobs = await ErrorLog.shared.attempt("cache", "读取物理实验缓存失败") {
            try await database.writer.read { db -> [Data] in
                try Row.fetchAll(db, sql: "SELECT json FROM phy_experiment WHERE studentId = ?", arguments: [cacheKey]).map { $0["json"] }
            }
        }
        return Self.sorted((blobs ?? []).compactMap { blob in
            ErrorLog.shared.attempt("cache", "解码物理实验缓存失败") { try JSONDecoder().decode(PhyExperiment.self, from: blob) }
        })
    }

    @discardableResult
    public func refresh(unifiedUsername: String) async throws -> [PhyExperiment] {
        let parsed = try PhyExpParser.parseRows(try await client.ruleManage())
        if parsed.rowCount > 0, parsed.items.isEmpty { throw GxuError.decoding("物理实验数据格式不正确") }
        let list = Self.sorted(parsed.items)
        let cacheKey = PracticeCache.key(for: unifiedUsername)
        let rows = try list.map { ($0.id, try JSONEncoder().encode($0)) }
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM phy_experiment WHERE studentId = ?", arguments: [cacheKey])
            for (id, json) in rows {
                try db.execute(
                    sql: "INSERT INTO phy_experiment (studentId, id, json) VALUES (?, ?, ?) ON CONFLICT(studentId, id) DO UPDATE SET json = excluded.json",
                    arguments: [cacheKey, id, json]
                )
            }
        }
        return list
    }

    static func sorted(_ list: [PhyExperiment]) -> [PhyExperiment] {
        list.sorted { ($0.dateText, $0.timeText, $0.id) < ($1.dateText, $1.timeText, $1.id) }
    }
}


public enum PhyExpOverrides {
    public static let courseNameKeyword = "物理实验"

    public static func cached(database: AppDatabase, unifiedUsername: String?, calendar: Calendar = .current) async -> [OccurrenceOverride] {
        guard let unifiedUsername else { return [] }
        let labs = await PhyExpRepository(database: database, client: OfflinePECClient()).cached(unifiedUsername: unifiedUsername)
        return overrides(for: labs, calendar: calendar)
    }

    static func overrides(for labs: [PhyExperiment], calendar: Calendar) -> [OccurrenceOverride] {
        labs.compactMap { lab in
            lab.date(calendar: calendar).map {
                OccurrenceOverride(date: $0, courseNameContains: courseNameKeyword, teacher: lab.teacher, venue: lab.place)
            }
        }
    }
}

private struct OfflinePECClient: PECClient {
    func ruleManage() async throws -> Data { throw GxuError.notLoggedIn(.unified) }
}
