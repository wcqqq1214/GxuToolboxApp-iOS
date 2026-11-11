import Foundation
import ScheduleKit

public struct ScheduleWidgetEntry: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case unavailable(ScheduleDataState)
        case stale
        case inClass
        case waiting
        case finished
    }

    public var date: Date
    public var phase: Phase
    public var current: WidgetCourse?
    public var upcoming: [WidgetCourse]
    public var tomorrow: [WidgetCourse]
    public var next: WidgetCourse?
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

    public var focus: WidgetCourse? { current ?? upcoming.first ?? next }
}

public enum ScheduleTimeline {
    public static let maxEntries = 24

    public static func entry(at date: Date, snapshot: NextCourses, calendar: Calendar = .current, hadClassesOn: Date? = nil) -> ScheduleWidgetEntry {
        guard snapshot.state == .ready else { return ScheduleWidgetEntry(date: date, phase: .unavailable(snapshot.state)) }

        let all = uniqueCourses(snapshot)
        let day = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day

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
            tomorrow: isStale ? [] : tomorrow, next: next, hadClassesToday: !today.isEmpty || (hadClassesOn.map { calendar.isDate($0, inSameDayAs: date) } ?? false)
        )
    }

    public static func entries(
        snapshot: NextCourses, now: Date, calendar: Calendar = .current, hadClassesOn: Date? = nil
    ) -> (entries: [ScheduleWidgetEntry], reloadAfter: Date) {
        var boundaries = Set<Date>()
        for course in uniqueCourses(snapshot) {
            if course.startsAt > now { boundaries.insert(course.startsAt) }
            if course.endsAt > now { boundaries.insert(course.endsAt) }
        }
        let base = calendar.startOfDay(for: max(now, snapshot.refreshedAt))
        for offset in 1...2 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: base), midnight > now { boundaries.insert(midnight) }
        }
        let dates = [now] + boundaries.sorted().prefix(maxEntries - 1)
        let entries = dates.map { entry(at: $0, snapshot: snapshot, calendar: calendar, hadClassesOn: hadClassesOn) }
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
    var markerHex: UInt32 {
        let colors = CoursePalette.macaron.colors
        var hash: UInt64 = 14695981039346656037
        for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return colors[Int(hash % UInt64(colors.count))]
    }
}
