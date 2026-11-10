import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage
import ScheduleKit

/// 物理实验课的一次上课（物理实验教学中心 PEC 的 `getRuleManage`）。
/// 字段名对照 RN 的 `PhyExpSchema`：id / zc 周次 / bjmc 班级 / skrq 日期(yyyyMMdd) / sksj 时间 / kcmc 课程 / xmmc 实验名 /
/// zjjsxm 教师 / fjbh 地点 / sysmc 实验室。
public struct PhyExperiment: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var week: String
    public var className: String
    /// `yyyyMMdd`
    public var dateText: String
    public var timeText: String
    public var courseName: String
    public var experimentName: String
    public var teacher: String
    public var location: String
    public var labName: String

    /// 上课日期（当天 00:00，按传入日历的时区）
    public func date(calendar: Calendar = .current) -> Date? {
        guard dateText.count == 8, let year = Int(dateText.prefix(4)), let month = Int(dateText.dropFirst(4).prefix(2)), let day = Int(dateText.suffix(2))
        else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// 显示用标题：实验名，没有就用课程名
    public var title: String { experimentName.isEmpty ? courseName : experimentName }
    /// 显示用地点：教室，没有就用实验室
    public var place: String { location.isEmpty ? labName : location }
}

/// PEC 返回体解析。外层 `{"d": "<JSON 字符串>"}`，里面是 `{"data": [...]}`，键名大小写不固定（RN 统一转小写）。
/// TODO(verify): 还没有用真实 PEC 响应验证（需要统一认证账号），字段名按 RN 的 schema 推断。
public enum PhyExpParser {
    public static func parse(_ data: Data) throws -> [PhyExperiment] { try parseRows(data).items }

    /// `rowCount` 是返回体里的原始行数。行数 > 0 但一条都解析不出来，说明字段名变了：调用方应当当成错误，不能把缓存清空。
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
        // JSON null 当作空，不能变成字面量 “<null>”
        let lowered = Dictionary(row.map { ($0.key.lowercased(), $0.value is NSNull ? "" : "\($0.value)") }, uniquingKeysWith: { first, _ in first })
        func value(_ key: String) -> String { (lowered[key] ?? "").trimmingCharacters(in: .whitespaces) }
        let date = value("skrq")
        guard !date.isEmpty else { return nil }   // 没有日期的行没法显示
        return PhyExperiment(
            id: value("id").isEmpty ? "\(date)-\(value("sksj"))-\(value("xmmc"))" : value("id"),
            week: value("zc"), className: value("bjmc"), dateText: date, timeText: value("sksj"),
            courseName: value("kcmc"), experimentName: value("xmmc"),
            teacher: value("zjjsxm"), location: value("fjbh"), labName: value("sysmc")
        )
    }
}

/// 物理实验平台客户端。抽成协议是为了测试时不用真连 PEC。
public protocol PECClient: Sendable {
    /// `getRuleManage` 的原始响应体
    func ruleManage() async throws -> Data
}

/// 用统一认证会话访问 PEC：先 SSO 登录，再 POST `getRuleManage`
public struct LivePECClient: PECClient {
    let unified: UnifiedAuthSession?

    public init(unified: UnifiedAuthSession?) { self.unified = unified }

    public func ruleManage() async throws -> Data {
        guard let unified else { throw GxuError.notLoggedIn(.unified) }
        try await unified.loginPEC()
        var request = URLRequest(url: URL(string: "https://pec.gxu.edu.cn/LMSmini/teacher/UI/wxInterface/syjx.asmx/getRuleManage")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["page": 1, "limit": 100])
        let (data, response) = try await unified.data(for: request)
        guard (200..<300).contains(response.statusCode) else { throw GxuError.http(status: response.statusCode, message: nil) }
        return data
    }
}

/// 物理实验课的本地缓存，按学号隔离。先读缓存，再 `refresh`；刷新失败保留旧缓存。
public struct PhyExpRepository: Sendable {
    private let database: AppDatabase
    private let client: any PECClient

    public init(database: AppDatabase, client: any PECClient) {
        self.database = database
        self.client = client
    }

    public func cached(studentId: String) async -> [PhyExperiment] {
        let blobs = try? await database.writer.read { db -> [Data] in
            try Row.fetchAll(db, sql: "SELECT json FROM phy_experiment WHERE studentId = ?", arguments: [studentId]).map { $0["json"] }
        }
        return Self.sorted((blobs ?? []).compactMap { try? JSONDecoder().decode(PhyExperiment.self, from: $0) })
    }

    @discardableResult
    public func refresh(studentId: String) async throws -> [PhyExperiment] {
        let parsed = try PhyExpParser.parseRows(try await client.ruleManage())
        if parsed.rowCount > 0, parsed.items.isEmpty { throw GxuError.decoding("物理实验数据格式不正确") }   // 保留旧缓存
        let list = Self.sorted(parsed.items)
        let rows = try list.map { ($0.id, try JSONEncoder().encode($0)) }
        try await database.writer.write { db in
            // 先删后插：已取消的实验课不残留
            try db.execute(sql: "DELETE FROM phy_experiment WHERE studentId = ?", arguments: [studentId])
            for (id, json) in rows {
                try db.execute(
                    sql: "INSERT INTO phy_experiment (studentId, id, json) VALUES (?, ?, ?) ON CONFLICT(studentId, id) DO UPDATE SET json = excluded.json",
                    arguments: [studentId, id, json]
                )
            }
        }
        return list
    }

    static func sorted(_ list: [PhyExperiment]) -> [PhyExperiment] {
        list.sorted { ($0.dateText, $0.timeText, $0.id) < ($1.dateText, $1.timeText, $1.id) }
    }
}


/// 物理实验课对课表的覆盖（RN v2.2：标题带“物理实验”的课，按上课日期换成 PEC 里的教师和地点）。只读本地缓存，不联网。
public enum PhyExpOverrides {
    public static let courseNameKeyword = "物理实验"

    public static func cached(database: AppDatabase, studentId: String, calendar: Calendar = .current) async -> [OccurrenceOverride] {
        let labs = await PhyExpRepository(database: database, client: OfflinePECClient()).cached(studentId: studentId)
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
