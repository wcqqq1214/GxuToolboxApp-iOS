import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage

/// 金工实训（工程训练中心 xlzxms）的一天安排
public struct EngTrainingDay: Codable, Sendable, Hashable, Identifiable {
    /// 接口里的日期文案，如 “10月8日”（没有年份）
    public var dateText: String
    /// 推断出年份后的日期（当天 00:00）
    public var date: Date
    public var name: String
    public var id: String { dateText }
}

/// 工程训练中心返回的是一张“安排表”：`datas[0]` 是单元格数组（startRow / startCol / colNumber / content）。
/// 对照 RN `EngTrainingScheduleScreen.getData`：第 2 行（startRow == 2）是日期表头；第 9 行（startRow == 9）的单元格是实训名称，
/// 按列区间落在对应日期下面。接口里日期没有年份，按“离今天最近的那一年”推断。
/// TODO(verify): 还没有用真实响应验证（需要统一认证账号 + 校园网），行号取自 RN 的写法。
public enum EngTrainingParser {
    private struct Cell {
        let startRow: Int, startCol: Int, colNumber: Int
        let content: String
    }

    public static func parse(_ data: Data, now: Date = .now, calendar: Calendar = .current) throws -> [EngTrainingDay] {
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
        return dates.compactMap { date -> EngTrainingDay? in
            guard let day = resolve(date.content, now: now, calendar: calendar) else { return nil }
            let exp = cells.first {
                $0.startRow == 9 && $0.startCol <= date.startCol && $0.startCol + $0.colNumber >= date.startCol + date.colNumber
            }
            return EngTrainingDay(dateText: date.content, date: day, name: exp?.content ?? "")
        }
        .sorted { $0.date < $1.date }
    }

    /// “10月8日” → 离 `now` 最近的那一年的 10 月 8 日
    static func resolve(_ text: String, now: Date, calendar: Calendar) -> Date? {
        let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard numbers.count >= 2 else { return nil }
        let year = calendar.component(.year, from: now)
        let candidates = [year - 1, year, year + 1].compactMap {
            calendar.date(from: DateComponents(year: $0, month: numbers[0], day: numbers[1]))
        }
        return candidates.min { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) }
    }
}

public protocol EngTrainingClient: Sendable {
    /// `stuPersonalArrangeTable` 的原始响应体
    func scheduleTable() async throws -> Data
}

public struct LiveEngTrainingClient: EngTrainingClient {
    let unified: UnifiedAuthSession?

    public init(unified: UnifiedAuthSession?) { self.unified = unified }

    public func scheduleTable() async throws -> Data {
        guard let unified else { throw GxuError.notLoggedIn(.unified) }
        let session = try await unified.loginEngTraining()
        var request = URLRequest(url: URL(string: "http://xlzxms.gxu.edu.cn/api/course-newedition-server/course/course/arrange/stuPersonalArrangeTable")!)
        request.setValue(session.token, forHTTPHeaderField: "authorization")
        let (data, response) = try await unified.data(for: request)
        guard (200..<300).contains(response.statusCode) else { throw GxuError.http(status: response.statusCode, message: nil) }
        return data
    }
}

/// 金工实训安排的本地缓存，按学号隔离；刷新失败保留旧缓存
public struct EngTrainingRepository: Sendable {
    private let database: AppDatabase
    private let client: any EngTrainingClient

    public init(database: AppDatabase, client: any EngTrainingClient) {
        self.database = database
        self.client = client
    }

    public func cached(studentId: String) async -> [EngTrainingDay] {
        let blobs = try? await database.writer.read { db -> [Data] in
            try Row.fetchAll(db, sql: "SELECT json FROM eng_training WHERE studentId = ?", arguments: [studentId]).map { $0["json"] }
        }
        return (blobs ?? []).compactMap { try? JSONDecoder().decode(EngTrainingDay.self, from: $0) }.sorted { $0.date < $1.date }
    }

    @discardableResult
    public func refresh(studentId: String, now: Date = .now) async throws -> [EngTrainingDay] {
        let days = try EngTrainingParser.parse(try await client.scheduleTable(), now: now)
        let rows = try days.map { ($0.dateText, try JSONEncoder().encode($0)) }
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM eng_training WHERE studentId = ?", arguments: [studentId])
            for (id, json) in rows {
                try db.execute(sql: "INSERT INTO eng_training (studentId, id, json) VALUES (?, ?, ?)", arguments: [studentId, id, json])
            }
        }
        return days
    }
}
