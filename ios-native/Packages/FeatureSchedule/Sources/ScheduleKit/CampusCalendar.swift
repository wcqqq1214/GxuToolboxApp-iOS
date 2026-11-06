import Foundation
import GxuFoundation
import GxuStorage

/// 补班规则：`workDate` 那天按 `restDate` 那天的课表上课（`restDate` 那天休息）。日期是 `YYYY-MM-DD`。
public struct ShiftRule: Codable, Sendable, Hashable {
    public var workDate: String
    public var restDate: String

    public init(workDate: String, restDate: String) {
        self.workDate = workDate
        self.restDate = restDate
    }

    /// 数据源里写成 `["补班日", "休息日"]`
    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        workDate = try c.decode(String.self)
        restDate = try c.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(workDate)
        try c.encode(restDate)
    }
}

/// 一段放假（含首尾两天）
public struct HolidayRange: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable { case national, local, school }

    public var title: String
    public var from: String
    public var to: String
    /// national = 法定节假日，local = 地方（如三月三），school = 学校安排（如运动会）；缺省按 national
    public var kind: Kind

    public init(title: String, from: String, to: String, kind: Kind = .national) {
        self.title = title
        self.from = from
        self.to = to
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey { case title, from, to, kind }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        from = try c.decode(String.self, forKey: .from)
        to = try c.decode(String.self, forKey: .to)
        kind = (try? c.decode(Kind.self, forKey: .kind)) ?? .national
    }
}

/// 学校日历：节假日 + 补班。数据来自可远程更新的 `data.json`，没联网时用上次缓存，再没有就用 App 内置的备份。
public struct CampusCalendar: Sendable, Equatable {
    public var timeShift: [ShiftRule]
    public var holidays: [HolidayRange]
    /// 远程数据最后一次成功更新的时间；还在用内置备份时为 nil
    public var updatedAt: Date?

    public init(timeShift: [ShiftRule] = [], holidays: [HolidayRange] = [], updatedAt: Date? = nil) {
        self.timeShift = timeShift
        self.holidays = holidays
        self.updatedAt = updatedAt
    }

    public static let empty = CampusCalendar()
}

/// `data.json` 的原样内容。两个字段都是可选的：老版本只有 `timeShift`，缺的字段回退到内置备份。
/// 单条数据格式不对时只丢弃那一条。
struct CampusCalendarFile: Codable, Sendable, Equatable {
    var timeShift: [ShiftRule]?
    var holidays: [HolidayRange]?

    private enum CodingKeys: String, CodingKey { case timeShift, holidays }

    init(timeShift: [ShiftRule]? = nil, holidays: [HolidayRange]? = nil) {
        self.timeShift = timeShift
        self.holidays = holidays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timeShift = try c.decodeIfPresent([Lossy<ShiftRule>].self, forKey: .timeShift)?.compactMap(\.value)
        holidays = try c.decodeIfPresent([Lossy<HolidayRange>].self, forKey: .holidays)?.compactMap(\.value)
    }

    private struct Lossy<T: Decodable & Sendable>: Decodable, Sendable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    static let fallback: CampusCalendarFile = {
        guard
            let url = Bundle.module.url(forResource: "campus-calendar-fallback", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(CampusCalendarFile.self, from: data)
        else { return CampusCalendarFile(timeShift: [], holidays: []) }
        return file
    }()

    func resolved(updatedAt: Date?) -> CampusCalendar {
        CampusCalendar(
            timeShift: timeShift ?? Self.fallback.timeShift ?? [],
            holidays: holidays ?? Self.fallback.holidays ?? [],
            updatedAt: updatedAt
        )
    }
}

/// 节假日 / 调课数据的“远程 + 本地缓存”。课表叠加、节假日页面、调课页面都读它，不要各自去请求。
public struct CampusCalendarRepository: Sendable {
    public typealias Fetch = @Sendable (URL) async throws -> Data

    public static let defaultURL = URL(string: "https://file.unde.site/GxuToolApp/data.json")!

    private let database: AppDatabase
    private let url: URL
    private let fetch: Fetch

    public init(database: AppDatabase, url: URL = defaultURL, fetch: @escaping Fetch = Self.urlSessionFetch) {
        self.database = database
        self.url = url
        self.fetch = fetch
    }

    /// 本地可用的日历：缓存优先，没有缓存或缓存缺字段时用内置备份。永远不抛错、不联网。
    public func current() async -> CampusCalendar {
        guard let cached = try? await readCache() else { return CampusCalendarFile.fallback.resolved(updatedAt: nil) }
        return cached.file.resolved(updatedAt: cached.updatedAt)
    }

    /// 联网更新并写缓存。失败时抛错、保留旧缓存；内容里一个字段都没有视为无效数据。
    @discardableResult
    public func refresh(now: Date = .now) async throws -> CampusCalendar {
        let data = try await fetch(url)
        guard let file = try? JSONDecoder().decode(CampusCalendarFile.self, from: data) else {
            throw GxuError.decoding("节假日数据格式不正确")
        }
        guard file.timeShift != nil || file.holidays != nil else {
            throw GxuError.invalidData("节假日数据为空")
        }
        let json = try JSONEncoder().encode(file)
        try await database.writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO campus_calendar (id, json, updatedAt) VALUES (1, ?, ?)
                ON CONFLICT(id) DO UPDATE SET json = excluded.json, updatedAt = excluded.updatedAt
                """,
                arguments: [json, now.timeIntervalSince1970]
            )
        }
        return file.resolved(updatedAt: now)
    }

    private func readCache() async throws -> (file: CampusCalendarFile, updatedAt: Date)? {
        try await database.writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT json, updatedAt FROM campus_calendar WHERE id = 1") else { return nil }
            let data: Data = row["json"]
            guard let file = try? JSONDecoder().decode(CampusCalendarFile.self, from: data) else { return nil }
            return (file, Date(timeIntervalSince1970: row["updatedAt"]))
        }
    }

    @Sendable public static func urlSessionFetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw GxuError.network("节假日数据获取失败")
            }
            return data
        } catch let error as GxuError {
            throw error
        } catch {
            if error.isCancellation { throw CancellationError() }
            throw GxuError.network("网络连接失败，请检查网络后重试")
        }
    }
}

/// 周网格里的“整天块”：假期，或没有落在假期里的调休休息日
public struct DayBlock: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable { case holiday(HolidayRange.Kind), rest }

    public let date: Date
    public let week: Int
    public let weekday: Int
    public let title: String
    public let kind: Kind
    /// 一段假期的第一天（UI 可以只在这一天写完整说明）
    public let isFirstDay: Bool

    public var id: String { "\(title)@\(week)-\(weekday)" }
}

/// 把假期和补班叠加到课表上。
/// - 假期、调休休息日：当天的课移除，并生成整天块；
/// - 补班日：保留当天原有的课，再加上休息日那天被调过来的课（带 `shiftedFrom` 标记）。
public enum CalendarOverlay {
    public static func apply(
        to occurrences: [CourseOccurrence], calendar campus: CampusCalendar, term: TermCalendar
    ) -> (occurrences: [CourseOccurrence], dayBlocks: [DayBlock]) {
        let cal = term.calendar
        let rules = campus.timeShift.compactMap { rule -> (work: Date, rest: Date)? in
            guard let work = TermCalendar.parseDay(rule.workDate, calendar: cal),
                  let rest = TermCalendar.parseDay(rule.restDate, calendar: cal) else { return nil }
            return (work, rest)
        }
        guard !rules.isEmpty || !campus.holidays.isEmpty else { return (occurrences, []) }

        let workDates = Set(rules.map(\.work))
        let restDates = Set(rules.map(\.rest))
        let holidays = holidayDays(campus.holidays, calendar: cal).filter { !workDates.contains($0.key) }

        var result = occurrences.filter { item in
            // 补课日保留当天原有的课（RN v2.2 `showPreShiftItems`）：被调过来的课和原有的课并排显示，不互相替换
            !restDates.contains(item.date) && holidays[item.date] == nil
        }
        for rule in rules {
            for source in occurrences where source.date == rule.rest {
                guard let moved = makeup(source, to: rule.work, term: term) else { continue }
                result.append(moved)
            }
        }
        result.sort { ($0.startsAt, $0.id) < ($1.startsAt, $1.id) }

        var blocks: [DayBlock] = []
        for (date, info) in holidays {
            if let block = dayBlock(on: date, title: info.title, kind: .holiday(info.kind), isFirst: info.isFirst, term: term) { blocks.append(block) }
        }
        for rest in restDates where holidays[rest] == nil {
            if let block = dayBlock(on: rest, title: "调休", kind: .rest, isFirst: true, term: term) { blocks.append(block) }
        }
        blocks.sort { ($0.date, $0.title) < ($1.date, $1.title) }
        return (result, blocks)
    }

    private static func holidayDays(
        _ ranges: [HolidayRange], calendar: Calendar
    ) -> [Date: (title: String, kind: HolidayRange.Kind, isFirst: Bool)] {
        var days: [Date: (title: String, kind: HolidayRange.Kind, isFirst: Bool)] = [:]
        for range in ranges {
            guard let from = TermCalendar.parseDay(range.from, calendar: calendar),
                  let to = TermCalendar.parseDay(range.to, calendar: calendar), from <= to else { continue }
            var day = from
            // 防止数据源写错日期导致死循环式的超长区间
            for _ in 0..<60 where day <= to {
                days[day] = (range.title, range.kind, day == from)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return days
    }

    private static func dayBlock(on date: Date, title: String, kind: DayBlock.Kind, isFirst: Bool, term: TermCalendar) -> DayBlock? {
        let week = term.week(containing: date)
        guard (1...term.weekCount).contains(week) else { return nil }
        return DayBlock(date: date, week: week, weekday: term.weekday(of: date), title: title, kind: kind, isFirstDay: isFirst)
    }

    private static func makeup(_ source: CourseOccurrence, to workDate: Date, term: TermCalendar) -> CourseOccurrence? {
        let week = term.week(containing: workDate)
        guard (1...term.weekCount).contains(week),
              let first = ClassPeriods.period(source.begin), let last = ClassPeriods.period(source.end),
              let start = term.calendar.date(bySettingHour: first.start.hour, minute: first.start.minute, second: 0, of: workDate),
              let end = term.calendar.date(bySettingHour: last.end.hour, minute: last.end.minute, second: 0, of: workDate)
        else { return nil }
        return CourseOccurrence(
            course: source.course, week: week, date: workDate, startsAt: start, endsAt: end,
            weekday: term.weekday(of: workDate), shiftedFrom: source.date
        )
    }
}
