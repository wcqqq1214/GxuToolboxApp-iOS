import Foundation
import GxuFoundation
import GxuNetworking

// 考勤系统接口：后端返回两层 `{code, message, data: {code: 600, msg, data: …}}`，
// `getData` 解掉外层，这里的 `AttendanceEnvelope` 是内层，`code == 600` 才是成功。
// TODO(verify): 没有真实账号，字段按 RN 的类型定义（type/api/auth/attendanceSystem.ts）写，解码都宽容；用 Mock 和单测验证。

struct AttendanceEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    var code: Int
    var msg: String?
    var data: T?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = c.lenientInt(.code) ?? -1
        msg = try? c.decodeIfPresent(String.self, forKey: .msg)
        data = try? c.decodeIfPresent(T.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey { case code, msg, data }

    /// 内层 code 不是 600 时抛错，文案用服务端的 `msg`
    func unwrap() throws -> T {
        guard code == 600 else { throw GxuError.invalidData(msg?.isEmpty == false ? msg! : "考勤系统返回了错误（\(code)）") }
        guard let data else { throw GxuError.invalidData("考勤系统返回的数据格式异常") }
        return data
    }
}

/// 学期校历（`/attendance/index-data` 的 `calendarList` 一项）
public struct AttendanceCalendar: Decodable, Sendable, Hashable, Identifiable {
    public var calendarId: Int
    /// 形如 `2025-1`
    public var calendarName: String
    /// `yyyy-MM-dd…`
    public var firstWeekBegin: String
    public var lastWeekEnd: String
    public var weekTotal: Int
    public var isCurrent: Bool

    public var id: Int { calendarId }

    public init(calendarId: Int, calendarName: String, firstWeekBegin: String, lastWeekEnd: String = "", weekTotal: Int = 20, isCurrent: Bool = false) {
        self.calendarId = calendarId
        self.calendarName = calendarName
        self.firstWeekBegin = firstWeekBegin
        self.lastWeekEnd = lastWeekEnd
        self.weekTotal = weekTotal
        self.isCurrent = isCurrent
    }

    private enum CodingKeys: String, CodingKey { case calendarId, calendarName, firstWeekBegin, lastWeekEnd, weekTotal, isCurrent }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calendarId = c.lenientInt(.calendarId) ?? 0
        calendarName = (try? c.decodeIfPresent(String.self, forKey: .calendarName)) ?? ""
        firstWeekBegin = (try? c.decodeIfPresent(String.self, forKey: .firstWeekBegin)) ?? ""
        lastWeekEnd = (try? c.decodeIfPresent(String.self, forKey: .lastWeekEnd)) ?? ""
        weekTotal = c.lenientInt(.weekTotal) ?? 20
        isCurrent = (c.lenientInt(.isCurrent) ?? 0) == 1
    }

    /// 学期第一周的周一
    public func firstDay(calendar: Calendar = .current) -> Date? { AttendanceDay.parse(firstWeekBegin, calendar: calendar) }

    /// 今天是第几周；不在 1…weekTotal 范围内返回 1（RN 同）
    public func currentWeek(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let first = firstDay(calendar: calendar) else { return 1 }
        let days = calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: now)).day ?? 0
        let week = Int((Double(days) / 7).rounded(.down)) + 1
        return (1...max(weekTotal, 1)).contains(week) ? week : 1
    }
}

struct AttendanceMenu: Decodable, Sendable {
    var calendarList: [AttendanceCalendar]

    private enum CodingKeys: String, CodingKey { case calendarList }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calendarList = (try? c.decodeIfPresent([AttendanceCalendar].self, forKey: .calendarList)) ?? []
    }
}

public enum AttendanceState: Int, Sendable, Hashable {
    case normal = 1, late = 2, absent = 4, notStarted = 5, noNeed = 100, unknown = 0

    public init(id: Int?) { self = id.flatMap(AttendanceState.init(rawValue:)) ?? .unknown }
}

/// 一条考勤记录（`/attendance/personal-data` 的 `records` 一项）
public struct AttendanceRecord: Decodable, Sendable, Hashable, Identifiable {
    public var day: String
    public var courseName: String
    public var roomName: String
    public var stateId: Int?
    public var stateName: String
    public var atdTime: String
    public var periodConnect: String

    public var state: AttendanceState { AttendanceState(id: stateId) }
    public var id: String { "\(day)|\(courseName)|\(periodConnect)|\(atdTime)" }

    public init(day: String, courseName: String, roomName: String = "", stateId: Int?, stateName: String = "", atdTime: String = "", periodConnect: String = "") {
        self.day = day
        self.courseName = courseName
        self.roomName = roomName
        self.stateId = stateId
        self.stateName = stateName
        self.atdTime = atdTime
        self.periodConnect = periodConnect
    }

    private enum CodingKeys: String, CodingKey { case day, courseName, roomName, atdStateId, atdStateName, atdTime, periodConnect }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = c.lenientText(.day)
        courseName = c.lenientText(.courseName)
        roomName = c.lenientText(.roomName)
        stateId = c.lenientInt(.atdStateId)
        stateName = c.lenientText(.atdStateName)
        atdTime = c.lenientText(.atdTime)
        periodConnect = c.lenientText(.periodConnect)
    }
}

struct AttendanceRecordPage: Decodable, Sendable {
    var records: [AttendanceRecord]
    var totalRecord: Int
    var totalPage: Int
    var pageIndex: Int

    private enum CodingKeys: String, CodingKey { case records, total_record, total_page, page_index }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        records = (try? c.decodeIfPresent([AttendanceRecord].self, forKey: .records)) ?? []
        totalRecord = c.lenientInt(.total_record) ?? records.count
        totalPage = c.lenientInt(.total_page) ?? 1
        pageIndex = c.lenientInt(.page_index) ?? 1
    }
}

/// 考勤课表里的一节课（已按 RN 的规则从二维表里解析出来）
public struct AttendanceCourse: Sendable, Hashable, Identifiable {
    public var day: String          // yyyy-MM-dd
    public var weekday: Int         // 1 = 周一
    public var name: String
    /// 起止节次（含）
    public var firstPeriod: Int
    public var lastPeriod: Int
    public var id: String { "\(day)|\(name)|\(firstPeriod)" }
}

struct AttendanceScheduleTable: Decodable, Sendable {
    struct Row: Decodable, Sendable {
        struct Cell: Decodable, Sendable {
            var weekDay: String
            var subjectName: String
            var connectCount: Int

            private enum CodingKeys: String, CodingKey { case weekDay, subjectName, connectCount }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                weekDay = c.lenientText(.weekDay)
                subjectName = c.lenientText(.subjectName)
                connectCount = c.lenientInt(.connectCount) ?? 0
            }
        }

        var courses: [Cell]

        private enum CodingKeys: String, CodingKey { case courses }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            courses = (try? c.decodeIfPresent([Cell].self, forKey: .courses)) ?? []
        }
    }

    var resTableRankList: [Row]

    private enum CodingKeys: String, CodingKey { case resTableRankList }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resTableRankList = (try? c.decodeIfPresent([Row].self, forKey: .resTableRankList)) ?? []
    }

    /// 移植自 RN `AttendanceCourseScheduleClass`：行是节次，`courses[day]`（day = 1…7，下标 0 是表头列）是那天那节的格子；
    /// 有课程名且 `connectCount > 0` 的格子是一门课的起点，连续占 `connectCount + 1` 节，之后跳过这些节。
    func courses() -> [AttendanceCourse] {
        var result: [AttendanceCourse] = []
        for day in 1...7 {
            var row = 0
            while row < resTableRankList.count {
                let cells = resTableRankList[row].courses
                if day < cells.count, !cells[day].subjectName.isEmpty, cells[day].connectCount > 0 {
                    let cell = cells[day]
                    result.append(AttendanceCourse(
                        day: String(cell.weekDay.prefix(10)), weekday: day, name: cell.subjectName,
                        firstPeriod: row + 1, lastPeriod: row + 1 + cell.connectCount
                    ))
                    row += cell.connectCount
                }
                row += 1
            }
        }
        return result
    }
}

enum AttendanceDay {
    /// `yyyy-MM-dd` 或更长的日期时间串，取前 10 位
    static func parse(_ text: String, calendar: Calendar = .current) -> Date? {
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
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
        if let v = try? decodeIfPresent(Double.self, forKey: key), v.isFinite { return Int(v) }
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

    func calendars() async throws -> [AttendanceCalendar] {
        let env = try await backend.getData("/attendance/index-data", auth: .attendance, as: AttendanceEnvelope<AttendanceMenu>.self)
        return try env.unwrap().calendarList
    }

    func records(calendarId: Int, page: Int = 1, pageSize: Int = 20) async throws -> AttendanceRecordPage {
        let env = try await backend.getData(
            "/attendance/personal-data",
            query: ["cal": String(calendarId), "page_index": String(page), "page_size": String(pageSize)],
            auth: .attendance, as: AttendanceEnvelope<AttendanceRecordPage>.self
        )
        return try env.unwrap()
    }

    func schedule(calendarId: Int, week: Int, userId: Int) async throws -> [AttendanceCourse] {
        let env = try await backend.getData(
            "/attendance/schedule",
            query: ["cal": String(calendarId), "currentWeek": String(week), "userId": String(userId)],
            auth: .attendance, as: AttendanceEnvelope<AttendanceScheduleTable>.self
        )
        return try env.unwrap().courses()
    }
}
