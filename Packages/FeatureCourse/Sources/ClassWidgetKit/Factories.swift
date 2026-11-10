import Foundation
import ScheduleKit

// ScheduleKit 的 WidgetCourse / NextCourses 没有公开构造器（只能从课表推算），
// 预览数据和测试通过 Codable 往返来构造。
private struct CourseMirror: Codable {
    var name, beginTime, endTime, index, teacher, room, date: String
    var startsAt, endsAt: Date
}

private struct SnapshotMirror: Codable {
    var state: ScheduleDataState
    var today, tomorrow: [WidgetCourse]
    var next: WidgetCourse?
    var nextRefreshAt: Date?
    var refreshedAt: Date
}

public extension WidgetCourse {
    static func make(
        name: String, room: String = "", teacher: String = "", startsAt: Date, endsAt: Date,
        index: String = "1-2", calendar: Calendar = .current
    ) -> WidgetCourse {
        func hm(_ d: Date) -> String {
            let c = calendar.dateComponents([.hour, .minute], from: d)
            return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        }
        let day = calendar.dateComponents([.year, .month, .day], from: startsAt)
        let mirror = CourseMirror(
            name: name, beginTime: hm(startsAt), endTime: hm(endsAt), index: index, teacher: teacher, room: room,
            date: String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0),
            startsAt: startsAt, endsAt: endsAt
        )
        // 字段与 WidgetCourse 的 Codable 键一一对应，编码后必能解回
        return try! JSONDecoder().decode(WidgetCourse.self, from: JSONEncoder().encode(mirror))
    }
}

public extension NextCourses {
    static func make(
        today: [WidgetCourse], tomorrow: [WidgetCourse] = [], next: WidgetCourse? = nil,
        refreshedAt: Date, state: ScheduleDataState = .ready
    ) -> NextCourses {
        let mirror = SnapshotMirror(
            state: state, today: today, tomorrow: tomorrow, next: next, nextRefreshAt: nil, refreshedAt: refreshedAt
        )
        return try! JSONDecoder().decode(NextCourses.self, from: JSONEncoder().encode(mirror))
    }
}
