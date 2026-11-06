import Foundation
import GxuFoundation
import GxuNetworking

// 考勤系统接口（RN v2.2 `src/features/attendance`）：后端 `GET /attendance/v2/personal`、`GET /attendance/v2/schedule`，
// 带 `Authorization: Token`（`auth: .attendance`）。RN 取 `res.data`，即响应体只有一层 `{code, data}`，没有 v1 的内层 `code == 600`。
// 学期用 `calendarId = 2 * year + term - 4033`（2025 秋 = 18），不再需要 `/attendance/index-data` 取校历。
// TODO(verify): 没有考勤账号，响应字段按 RN 的用法（RecordScreen / RecordCard / useScheduleTable）写，解码都宽容；用 Mock 和单测验证，后续测试。

/// 考勤系统的学期编号：和 RN 一致 `2 * year + term - 4033`
public enum AttendanceCalendarID {
    public static func id(year: Int, term: Int) -> Int { 2 * year + term - 4033 }
}

public enum AttendanceState: Int, Sendable, Hashable {
    case normal = 1, late = 2, absent = 4, notStarted = 5, noNeed = 100, unknown = 0

    public init(id: Int?) { self = id.flatMap(AttendanceState.init(rawValue:)) ?? .unknown }

    /// 文字说明（图标之外不能只靠颜色和形状区分）
    public var label: String {
        switch self {
        case .normal: "正常"
        case .late: "迟到"
        case .absent: "缺勤"
        case .notStarted: "未开始"
        case .noNeed: "无需打卡"
        case .unknown: "状态未知"
        }
    }
}

/// 一条考勤记录（`/attendance/v2/personal` 的 `items` 一项）
public struct AttendanceRecord: Decodable, Sendable, Hashable, Identifiable {
    public var date: String
    public var courseName: String
    public var roomName: String
    public var statusCode: Int?
    public var statusName: String
    /// 节次文案：`periodLabel`，没有就用 `periodRange`
    public var periodText: String
    /// 原始的节次范围（如 `1,2`），和课表的 `AttendanceCourse.id` 对应用
    public var periodRange: String

    public var state: AttendanceState { AttendanceState(id: statusCode) }
    public var id: String { "\(date)|\(courseName)|\(periodRange)|\(statusName)" }

    public init(date: String, courseName: String, roomName: String = "", statusCode: Int?, statusName: String = "", periodText: String = "", periodRange: String = "") {
        self.date = date
        self.courseName = courseName
        self.roomName = roomName
        self.statusCode = statusCode
        self.statusName = statusName
        self.periodText = periodText
        self.periodRange = periodRange
    }

    private enum CodingKeys: String, CodingKey { case date, courseName, roomName, statusCode, statusName, periodLabel, periodRange }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = c.lenientText(.date)
        courseName = c.lenientText(.courseName)
        roomName = c.lenientText(.roomName)
        statusCode = c.lenientInt(.statusCode)
        statusName = c.lenientText(.statusName)
        let label = c.lenientText(.periodLabel)
        periodRange = c.lenientText(.periodRange)
        periodText = label.isEmpty ? periodRange : label
    }

    /// 迟到或缺勤（RN：statusCode 2 或 4）
    public var isAbnormal: Bool { statusCode == 2 || statusCode == 4 }
}

struct AttendanceRecordPage: Decodable, Sendable {
    var items: [AttendanceRecord]

    private enum CodingKeys: String, CodingKey { case items }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([AttendanceRecord].self, forKey: .items)) ?? []
    }
}

/// 考勤课表里的一节课（`/attendance/v2/schedule` 的 `rows[].courses[]`，规则同 RN `useScheduleTable`）
public struct AttendanceCourse: Sendable, Hashable, Identifiable {
    public var day: String          // yyyy-MM-dd
    public var name: String
    public var room: String
    /// 起止节次（含）
    public var firstPeriod: Int
    public var lastPeriod: Int
    /// 和考勤记录对应用的键：`<日期>-<起,止>`（RN 的 `item.id`）
    public var id: String { "\(day)-\(firstPeriod),\(lastPeriod)" }
}

struct AttendanceSchedule: Decodable, Sendable {
    struct Row: Decodable, Sendable {
        struct Cell: Decodable, Sendable {
            var date: String
            var subjectId: Int?
            var subjectName: String
            var periods: [Int]
            var connectedCount: Int
            var roomName: String

            private enum CodingKeys: String, CodingKey { case date, subjectId, subjectName, periods, connectedCount, roomName }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                date = c.lenientText(.date)
                subjectId = c.lenientInt(.subjectId)
                subjectName = c.lenientText(.subjectName)
                periods = ((try? c.decodeIfPresent([Int].self, forKey: .periods)) ?? nil) ?? []
                connectedCount = c.lenientInt(.connectedCount) ?? 0
                roomName = c.lenientText(.roomName)
            }
        }

        var date: String
        var courses: [Cell]

        private enum CodingKeys: String, CodingKey { case date, courses }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            date = c.lenientText(.date)
            courses = (try? c.decodeIfPresent([Cell].self, forKey: .courses)) ?? []
        }
    }

    var totalWeeks: Int
    var rows: [Row]

    private enum CodingKeys: String, CodingKey { case totalWeeks, rows }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalWeeks = c.lenientInt(.totalWeeks) ?? 20
        rows = (try? c.decodeIfPresent([Row].self, forKey: .rows)) ?? []
    }

    /// 移植自 RN `useScheduleTable`：没有课程名（且 subjectId 为空 / 0）的格子丢弃；日期取格子自己的 `date`，没有就用行的 `date`；
    /// 起止节次取 `periods` 的首尾，没有就用行号和连续节数；只占一节的（起止相同）不是课程起点，丢弃
    func courses() -> [AttendanceCourse] {
        var result: [AttendanceCourse] = []
        for (rowIndex, row) in rows.enumerated() {
            for cell in row.courses {
                if (cell.subjectId == nil || cell.subjectId == 0) && cell.subjectName.isEmpty { continue }
                let day = String((cell.date.isEmpty ? row.date : cell.date).prefix(10))
                guard !day.isEmpty, !cell.subjectName.isEmpty else { continue }
                let begin = cell.periods.first ?? rowIndex + 1
                // 连续节数是服务端给的，离谱的值（如 Int.max）加法会溢出崩溃：限制在合理范围内
                let end = cell.periods.last ?? begin + min(max(cell.connectedCount, 0), 100)
                guard begin != end else { continue }
                result.append(AttendanceCourse(day: day, name: cell.subjectName, room: cell.roomName, firstPeriod: begin, lastPeriod: end))
            }
        }
        return result
    }
}

enum AttendanceDay {
    /// `yyyy-MM-dd` 或更长的日期时间串，取前 10 位
    static func parse(_ text: String, calendar: Calendar = .current) -> Date? {
        var calendar = calendar
        if calendar.identifier != .gregorian {   // 设备日历为佛历 / 农历等时，年月日不是公历
            var g = Calendar(identifier: .gregorian); g.timeZone = calendar.timeZone; g.locale = calendar.locale; calendar = g
        }
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let comps = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: comps) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        guard back.year == parts[0], back.month == parts[1], back.day == parts[2] else { return nil }   // 无效日期不顺延
        return date
    }
}

private extension KeyedDecodingContainer {
    func lenientText(_ key: Key) -> String {
        if let v = try? decodeIfPresent(String.self, forKey: key) { return v.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return String(v) }
        return ""
    }

    func lenientInt(_ key: Key) -> Int? {
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v }
        // 超出 Int 范围的数字转 Int 会直接崩溃，当作缺失处理
        if let v = try? decodeIfPresent(Double.self, forKey: key), v.isFinite, abs(v) < 1e15 { return Int(v) }
        if let v = try? decodeIfPresent(String.self, forKey: key) { return Int(v.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
}

/// 汇总：每种状态多少条
public struct AttendanceSummary: Equatable, Sendable {
    public var normal = 0, late = 0, absent = 0, other = 0
    public var total: Int { normal + late + absent + other }

    public init(_ records: [AttendanceRecord]) {
        for r in records {
            switch r.state {
            case .normal: normal += 1
            case .late: late += 1
            case .absent: absent += 1
            case .notStarted, .noNeed, .unknown: other += 1
            }
        }
    }
}

public struct AttendanceAPI: Sendable {
    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    /// 一次取整个学期的记录（RN 同样 `pageSize = 500`、`day DESC`），不分页
    func records(year: Int, term: Int) async throws -> [AttendanceRecord] {
        let page = try await backend.getData(
            "/attendance/v2/personal",
            query: ["calendarId": String(AttendanceCalendarID.id(year: year, term: term)), "pageSize": "500", "orderBy": "day DESC"],
            auth: .attendance, as: AttendanceRecordPage?.self
        )
        return page?.items ?? []
    }

    func schedule(year: Int, term: Int, week: Int, userId: Int) async throws -> (courses: [AttendanceCourse], totalWeeks: Int)? {
        let table = try await backend.getData(
            "/attendance/v2/schedule",
            query: ["calendarId": String(AttendanceCalendarID.id(year: year, term: term)), "currentWeek": String(week), "userId": String(userId)],
            auth: .attendance, as: AttendanceSchedule?.self
        )
        return table.map { ($0.courses(), $0.totalWeeks) }
    }
}
