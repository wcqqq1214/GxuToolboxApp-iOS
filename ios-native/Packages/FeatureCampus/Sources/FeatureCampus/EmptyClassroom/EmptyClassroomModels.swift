import Foundation

/// 空闲教室（RN `src/features/emptyClassroom`）的模型和纯逻辑。数据是全校公共数据（不是个人数据），所以表里没有 studentId。
public enum EmptyClassroomConstants {
    /// 首选页大小；后端升级后可一次取回一个节次的全部教室
    public static let pageSize = 10_000
    /// 单次节次查询最多翻页数
    public static let maxPages = 10
    public static let days = 7
    public static let periods = 13
    /// 按时间查询结果每页的教室数
    public static let availableRoomPageSize = 40
    /// 周选择固定展示 1–20 周
    public static let maxWeeks = 20
    /// 两次缓存“开始”之间的最小间隔（秒）
    public static let cooldown: TimeInterval = 60
    public static let slotRowBytes = 38
    public static let roomRowBytes = 130
}

/// 教室业务键：楼栋 + NUL + 教室名。接口没有稳定的教室编号，只能这样标识。
public func emptyRoomKey(_ building: String, _ name: String) -> String {
    "\(building.trimmingCharacters(in: .whitespaces))\u{0}\(name.trimmingCharacters(in: .whitespaces))"
}

/// 后端清洗后的一页空闲教室数据（`GET /jw/emptyClassroom`）。字段宽容解码：数字 / 字符串 / null 都接受。
public struct ClassroomPage: Decodable, Sendable, Equatable {
    public struct Item: Decodable, Sendable, Equatable {
        public var classroomName: String
        public var building: String
        public var placeType: String
        public var seatCount: String
        public var seatCountForExam: String
        public var owner: String
        public var allowToUse: String

        public init(classroomName: String, building: String, placeType: String = "", seatCount: String = "", seatCountForExam: String = "", owner: String = "", allowToUse: String = "") {
            self.classroomName = classroomName
            self.building = building
            self.placeType = placeType
            self.seatCount = seatCount
            self.seatCountForExam = seatCountForExam
            self.owner = owner
            self.allowToUse = allowToUse
        }

        private enum CodingKeys: String, CodingKey { case classroomName, building, placeType, seatCount, seatCountForExam, owner, allowToUse }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // classroomName / building 接口必填
            classroomName = try c.decode(String.self, forKey: .classroomName)
            building = try c.decode(String.self, forKey: .building)
            placeType = c.text(.placeType)
            seatCount = c.text(.seatCount)
            seatCountForExam = c.text(.seatCountForExam)
            owner = c.text(.owner)
            allowToUse = c.text(.allowToUse)
        }
    }

    public var totalPage: Int?
    public var totalCount: Int?
    public var items: [Item]

    public init(totalPage: Int? = nil, totalCount: Int? = nil, items: [Item]) {
        self.totalPage = totalPage
        self.totalCount = totalCount
        self.items = items
    }

    private enum CodingKeys: String, CodingKey { case totalPage, totalCount, items }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalPage = c.count(.totalPage)
        totalCount = c.count(.totalCount)
        // items 不是数组：不能当成“没有空教室”，由调用方当成异常（通常是教务登录失效）
        items = try c.decode([Item].self, forKey: .items)
    }
}

private extension KeyedDecodingContainer {
    /// null / 缺失 / 数字 都转成字符串
    func text(_ key: Key) -> String {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let n = try? decode(Int.self, forKey: key) { return String(n) }
        if let d = try? decode(Double.self, forKey: key) { return String(d) }
        return ""
    }

    /// 非负整数，兼容后端把数字序列化成字符串
    func count(_ key: Key) -> Int? {
        if let n = try? decode(Int.self, forKey: key) { return n >= 0 ? n : nil }
        if let s = try? decode(String.self, forKey: key), let n = Int(s.trimmingCharacters(in: .whitespaces)) { return n >= 0 ? n : nil }
        return nil
    }
}

/// 教室元数据（座位数已转 Int?）
public struct RoomPayload: Sendable, Equatable {
    public var key: String
    public var building: String
    public var name: String
    public var placeType: String
    public var seatCount: Int?
    public var seatCountForExam: Int?
    public var owner: String
    public var allowToUse: String
}

/// 一个教学日的抓取结果：教室元数据 + 每间教室当天空闲的节次
public struct DayPayload: Sendable, Equatable {
    public var day: Int
    public var rooms: [String: RoomPayload]
    /// roomKey → 空闲节次（升序、去重）
    public var freePeriods: [String: [Int]]
}

/// 教室维表的一行
public struct RoomRecord: Sendable, Hashable, Identifiable {
    public var id: Int64
    public var building: String
    public var name: String
    public var placeType: String
    public var seatCount: Int?
    public var seatCountForExam: Int?
    public var owner: String
    public var allowToUse: String
}

public struct WeekSnapshot: Sendable, Hashable {
    public var year: Int
    public var term: Int
    public var week: Int
    public var fetchedAt: Date
    public var completedDays: Int
    public var slotCount: Int
    public var roomCount: Int
    public var complete: Bool
}

public struct RoomBuildingSummary: Sendable, Hashable {
    /// 空串表示教务没返回可识别的楼栋
    public var building: String
    public var roomCount: Int
}

public struct FreePeriodRow: Sendable, Hashable {
    public var week: Int
    public var day: Int
    public var period: Int
}

/// 合并后的连续空闲段
public struct FreeRun: Sendable, Hashable, Identifiable {
    public var week: Int
    public var day: Int
    /// 起止节次，1-based，含
    public var begin: Int
    public var end: Int
    public var id: String { "\(week)-\(day)-\(begin)-\(end)" }
    public var length: Int { end - begin + 1 }
}

public struct AvailableRoomPeriodRow: Sendable, Hashable {
    public var room: RoomRecord
    public var week: Int
    public var day: Int
    public var period: Int
}

/// 时间查询结果：教室 + 选中范围内合并后的空闲区间
public struct RoomAvailabilityResult: Sendable, Hashable, Identifiable {
    public var room: RoomRecord
    public var freeRuns: [FreeRun]
    public var freePeriodCount: Int
    public var longestFreeRun: Int
    public var firstFreePeriod: Int?
    public var id: Int64 { room.id }
}

public enum TimeQuerySortMode: String, Sendable { case `default`, free }
public enum TimeQuerySortDirection: String, Sendable { case asc, desc }

public enum EmptyClassroomLogic {
    /// 把同一周、同一天内严格相邻的节次合并成连续空闲段。输入顺序无关、重复只计一次、越界行忽略，不跨天、不对午休做特殊处理。
    public static func buildFreeRuns(_ rows: [FreePeriodRow]) -> [FreeRun] {
        let sorted = rows
            .filter { (1...EmptyClassroomConstants.maxWeeks).contains($0.week) && (1...EmptyClassroomConstants.days).contains($0.day) && (1...EmptyClassroomConstants.periods).contains($0.period) }
            .sorted { ($0.week, $0.day, $0.period) < ($1.week, $1.day, $1.period) }
        var runs: [FreeRun] = []
        var current: FreeRun?
        for row in sorted {
            if var run = current, run.week == row.week, run.day == row.day {
                if row.period == run.end { continue }
                if row.period == run.end + 1 {
                    run.end = row.period
                    current = run
                    continue
                }
            }
            if let current { runs.append(current) }
            current = FreeRun(week: row.week, day: row.day, begin: row.period, end: row.period)
        }
        if let current { runs.append(current) }
        return runs
    }

    /// 单日、节次范围内的空闲行按教室聚合；顺序沿用输入（SQL 的楼栋 / 教室顺序）
    public static func buildResults(_ rows: [AvailableRoomPeriodRow]) -> [RoomAvailabilityResult] {
        var order: [Int64] = []
        var grouped: [Int64: (room: RoomRecord, week: Int, day: Int, periods: Set<Int>)] = [:]
        for row in rows where row.period >= 1 {
            if grouped[row.room.id] != nil {
                grouped[row.room.id]?.periods.insert(row.period)
            } else {
                order.append(row.room.id)
                grouped[row.room.id] = (row.room, row.week, row.day, [row.period])
            }
        }
        return order.compactMap { id -> RoomAvailabilityResult? in
            guard let group = grouped[id] else { return nil }
            let runs = buildFreeRuns(group.periods.map { FreePeriodRow(week: group.week, day: group.day, period: $0) })
            return RoomAvailabilityResult(
                room: group.room, freeRuns: runs,
                freePeriodCount: runs.reduce(0) { $0 + $1.length },
                longestFreeRun: runs.map(\.length).max() ?? 0,
                firstFreePeriod: runs.first?.begin
            )
        }
    }

    /// 与 SQLite BINARY 排序一致的逐码点比较（分页边界也用它，不能用本地化比较，否则后页会插到旧列表前面）
    static func compareDatabaseText(_ a: String, _ b: String) -> Int {
        let l = Array(a.unicodeScalars), r = Array(b.unicodeScalars)
        for i in 0..<min(l.count, r.count) where l[i].value != r[i].value { return Int(l[i].value) - Int(r[i].value) }
        return l.count - r.count
    }

    static func compareRoom(_ a: RoomRecord, _ b: RoomRecord) -> Bool {
        let building = compareDatabaseText(a.building, b.building)
        if building != 0 { return building < 0 }
        let name = compareDatabaseText(a.name, b.name)
        if name != 0 { return name < 0 }
        return a.id < b.id
    }

    /// 默认按名称，或按选中范围内的空闲节数排序（同节数先比首次空闲节次，再按楼栋 / 教室名稳定排序）
    public static func sort(_ results: [RoomAvailabilityResult], mode: TimeQuerySortMode, direction: TimeQuerySortDirection) -> [RoomAvailabilityResult] {
        results.sorted { left, right in
            if mode == .default { return compareRoom(left.room, right.room) }
            if left.freePeriodCount != right.freePeriodCount {
                return direction == .desc ? left.freePeriodCount > right.freePeriodCount : left.freePeriodCount < right.freePeriodCount
            }
            let l = left.firstFreePeriod ?? .max, r = right.firstFreePeriod ?? .max
            if l != r { return l < r }
            return compareRoom(left.room, right.room)
        }
    }

    /// 按楼栋切成分组，空楼栋统一显示“其他楼栋”；分组顺序沿用结果中首次出现的顺序
    public static func group(_ results: [RoomAvailabilityResult]) -> [(title: String, items: [RoomAvailabilityResult])] {
        var order: [String] = []
        var map: [String: [RoomAvailabilityResult]] = [:]
        for result in results {
            let title = result.room.building.trimmingCharacters(in: .whitespaces).isEmpty ? "其他楼栋" : result.room.building
            if map[title] == nil { order.append(title) }
            map[title, default: []].append(result)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    /// 估算缓存占用（字节）
    public static func estimatedBytes(slots: Int, rooms: Int) -> Int {
        slots * EmptyClassroomConstants.slotRowBytes + rooms * EmptyClassroomConstants.roomRowBytes
    }
}
