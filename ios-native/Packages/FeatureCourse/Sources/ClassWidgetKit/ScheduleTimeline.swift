import Foundation
import ScheduleKit

/// 小组件在某一时刻要显示的内容。由 App 写入 App Group 的 `NextCourses` 快照推算出来，
/// 小组件进程不联网、不读数据库。
public struct ScheduleWidgetEntry: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// 没有可用数据（未登录 / 没有课表 / 没有开学日 / 出错）
        case unavailable(ScheduleDataState)
        /// 快照太旧，覆盖不到这一天，需要打开 App 同步
        case stale
        case inClass
        /// 今天还有课没开始
        case waiting
        /// 今天的课已经上完（或今天没课）
        case finished
    }

    public var date: Date
    public var phase: Phase
    /// 正在上的课
    public var current: WidgetCourse?
    /// 今天还没开始的课，按时间升序（不含正在上的）
    public var upcoming: [WidgetCourse]
    public var tomorrow: [WidgetCourse]
    /// 下一节还没开始的课，可能不在今天 / 明天
    public var next: WidgetCourse?
    /// 今天是否有过课（用来区分"今天没课"和"今天的课上完了"）
    public var hadClassesToday: Bool

    public init(
        date: Date, phase: Phase, current: WidgetCourse? = nil, upcoming: [WidgetCourse] = [],
        tomorrow: [WidgetCourse] = [], next: WidgetCourse? = nil, hadClassesToday: Bool = false
    ) {
        self.date = date
        self.phase = phase
        self.current = current
        self.upcoming = upcoming
        self.tomorrow = tomorrow
        self.next = next
        self.hadClassesToday = hadClassesToday
    }

    /// 要重点展示的那一节：正在上的，否则今天的下一节，否则 `next`
    public var focus: WidgetCourse? { current ?? upcoming.first ?? next }
}

public enum ScheduleTimeline {
    /// 一个 Timeline 最多放多少个条目（每节课开始 / 结束各一个，一天最多 6 节课 ≈ 12 个）
    public static let maxEntries = 24

    public static func entry(at date: Date, snapshot: NextCourses, calendar: Calendar = .current) -> ScheduleWidgetEntry {
        guard snapshot.state == .ready else { return ScheduleWidgetEntry(date: date, phase: .unavailable(snapshot.state)) }

        let all = uniqueCourses(snapshot)
        let day = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day

        // 快照只覆盖"生成那天 + 次日"。date 晚于这个范围，就只剩 next 可信
        let coverageEnd = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: snapshot.refreshedAt)) ?? day
        let isStale = day >= coverageEnd

        let today = all.filter { calendar.isDate($0.startsAt, inSameDayAs: date) }
        let current = today.first { $0.startsAt <= date && date < $0.endsAt }
        let upcoming = today.filter { $0.startsAt > date }
        let tomorrow = all.filter { calendar.isDate($0.startsAt, inSameDayAs: nextDay) }
        let next = all.first { $0.startsAt > date }

        let phase: ScheduleWidgetEntry.Phase
        if isStale { phase = .stale }
        else if current != nil { phase = .inClass }
        else if !upcoming.isEmpty { phase = .waiting }
        else { phase = .finished }

        return ScheduleWidgetEntry(
            date: date, phase: phase, current: isStale ? nil : current, upcoming: isStale ? [] : upcoming,
            tomorrow: isStale ? [] : tomorrow, next: next, hadClassesToday: !today.isEmpty
        )
    }

    /// 从 `now` 起的条目：现在一个，之后每节课开始和结束各一个，另加每天零点一个（日期翻页）。
    /// `reloadAfter` 是最后一个条目的时间，WidgetKit 之后会重新请求时间线。
    public static func entries(
        snapshot: NextCourses, now: Date, calendar: Calendar = .current
    ) -> (entries: [ScheduleWidgetEntry], reloadAfter: Date) {
        var boundaries = Set<Date>()
        for course in uniqueCourses(snapshot) {
            if course.startsAt > now { boundaries.insert(course.startsAt) }
            if course.endsAt > now { boundaries.insert(course.endsAt) }
        }
        // 零点：快照生成当天及之后两天
        let base = calendar.startOfDay(for: max(now, snapshot.refreshedAt))
        for offset in 1...2 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: base), midnight > now { boundaries.insert(midnight) }
        }
        let dates = [now] + boundaries.sorted().prefix(maxEntries - 1)
        let entries = dates.map { entry(at: $0, snapshot: snapshot, calendar: calendar) }
        return (entries, dates.last ?? now)
    }

    private static func uniqueCourses(_ snapshot: NextCourses) -> [WidgetCourse] {
        var seen = Set<String>()
        var result: [WidgetCourse] = []
        for course in snapshot.today + snapshot.tomorrow + (snapshot.next.map { [$0] } ?? []) where seen.insert(course.id).inserted {
            result.append(course)
        }
        return result.sorted { ($0.startsAt, $0.id) < ($1.startsAt, $1.id) }
    }
}

public extension WidgetCourse {
    /// 小组件里用的课程标记色（色盘基色）。小组件进程拿不到 App 里按整张课表分配的颜色，
    /// 这里按课程名稳定地取一个，同名课程在各个小组件里颜色一致。
    var markerHex: UInt32 {
        let colors = CoursePalette.macaron.colors
        var hash: UInt64 = 14695981039346656037
        for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return colors[Int(hash % UInt64(colors.count))]
    }
}
