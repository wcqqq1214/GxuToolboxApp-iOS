import ClassWidgetKit
import GxuDesign
import ScheduleKit
import SwiftUI
import WidgetKit

public struct ScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    var entry: ScheduleWidgetEntry
    /// 仅用于进程内渲染（设计自查）；在小组件里由系统环境决定
    var familyOverride: WidgetFamily?
    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    public init(entry: ScheduleWidgetEntry, family: WidgetFamily? = nil) {
        self.entry = entry
        self.familyOverride = family
    }

    public var body: some View {
        Group {
            switch family {
            case .systemSmall: SmallView(entry: entry)
            case .systemMedium: MediumView(entry: entry)
            case .systemLarge: LargeView(entry: entry)
            case .accessoryRectangular: RectangularView(entry: entry)
            case .accessoryInline: InlineView(entry: entry)
            default: SmallView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { Color(uiColor: .secondarySystemBackground) }
        .widgetURL(URL(string: "gxutool://schedule"))
    }
}

// MARK: 文案

private extension ScheduleWidgetEntry {
    /// 标题小字：说明 focus 是什么
    var headline: String {
        switch phase {
        case .unavailable, .stale: return "课表"
        case .inClass: return "正在上课"
        case .waiting: return "下一节"
        case .finished: return next == nil ? "课表" : (hadClassesToday ? "今天的课已上完" : "今天没有课")
        }
    }

    var symbol: String {
        switch phase {
        case .inClass: "book.fill"
        case .waiting: "clock"
        case .finished: "checkmark.circle"
        case .unavailable, .stale: "calendar"
        }
    }

    var message: String? {
        switch phase {
        case .unavailable(let state):
            switch state {
            case .missingSchedule: "打开西大工具箱同步课表"
            case .missingStartDay: "暂时无法确定教学周"
            default: "课表暂不可用"
            }
        case .stale: "打开西大工具箱更新课表"
        default: nil
        }
    }
}

private func timeRange(_ c: WidgetCourse) -> String { "\(c.beginTime)–\(c.endTime)" }

/// 不在今天时带上星期，例如"周四 08:00"
private func dayPrefixed(_ c: WidgetCourse, relativeTo date: Date) -> String {
    let cal = Calendar.current
    if cal.isDate(c.startsAt, inSameDayAs: date) { return timeRange(c) }
    if let tomorrow = cal.date(byAdding: .day, value: 1, to: date), cal.isDate(c.startsAt, inSameDayAs: tomorrow) {
        return "明天 \(timeRange(c))"
    }
    let weekday = (cal.component(.weekday, from: c.startsAt) + 5) % 7 + 1
    return "\(WeekdayName.full(weekday)) \(timeRange(c))"
}

// MARK: 部件

private struct StatusLabel: View {
    var entry: ScheduleWidgetEntry
    var body: some View {
        Label(entry.headline, systemImage: entry.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tint)
            .widgetAccentable()
            .lineLimit(1)
    }
}

private struct MessageView: View {
    var entry: ScheduleWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StatusLabel(entry: entry)
            Spacer(minLength: 0)
            Text(entry.message ?? "").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// 一节课的焦点展示（小组件左侧 / 小尺寸整体）
private struct FocusView: View {
    var entry: ScheduleWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            StatusLabel(entry: entry)
            Spacer(minLength: 4)
            if let course = entry.focus {
                Text(course.name).font(.headline).lineLimit(2).minimumScaleFactor(0.85)
                Text(dayPrefixed(course, relativeTo: entry.date)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                if !course.room.isEmpty {
                    Label(course.room, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("暂无课程").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct CourseRow: View {
    var course: WidgetCourse
    var highlighted = false
    var showsDay = false
    var date: Date

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(CourseTint(hex: course.markerHex).marker)
                .frame(width: 3)
                .widgetAccentable(highlighted)
            VStack(alignment: .leading, spacing: 0) {
                Text(course.name).font(.subheadline.weight(highlighted ? .semibold : .regular)).lineLimit(1)
                Text([showsDay ? dayPrefixed(course, relativeTo: date) : timeRange(course), course.room].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: 主屏

private struct SmallView: View {
    var entry: ScheduleWidgetEntry
    var body: some View {
        if entry.message != nil { MessageView(entry: entry) } else { FocusView(entry: entry) }
    }
}

private struct MediumView: View {
    var entry: ScheduleWidgetEntry

    private var rest: [WidgetCourse] {
        var list = entry.upcoming
        if entry.current == nil, !list.isEmpty { list.removeFirst() }   // 第一节已在左侧
        return list
    }

    var body: some View {
        if entry.message != nil {
            MessageView(entry: entry)
        } else {
            HStack(alignment: .top, spacing: 14) {
                FocusView(entry: entry)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text(rest.isEmpty ? "之后" : "接下来").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    if rest.isEmpty {
                        Text(entry.tomorrow.isEmpty ? "今天没有更多课程" : "今天没有更多课程")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if let first = entry.tomorrow.first {
                            CourseRow(course: first, showsDay: true, date: entry.date)
                        }
                    } else {
                        ForEach(rest.prefix(3)) { CourseRow(course: $0, date: entry.date) }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct LargeView: View {
    var entry: ScheduleWidgetEntry

    private var today: [WidgetCourse] { [entry.current].compactMap { $0 } + entry.upcoming }

    var body: some View {
        if entry.message != nil {
            MessageView(entry: entry)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StatusLabel(entry: entry)
                    Spacer()
                    Text(entry.date.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "zh_CN"))))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if today.isEmpty {
                    Text(entry.hadClassesToday ? "今天的课都上完了" : "今天没有课").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(today.prefix(5)) { CourseRow(course: $0, highlighted: $0.id == entry.current?.id, date: entry.date) }
                }
                if !entry.tomorrow.isEmpty {
                    Divider()
                    Text("明天").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(entry.tomorrow.prefix(today.count > 3 ? 2 : 3)) { CourseRow(course: $0, date: entry.date) }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: 锁屏

private struct RectangularView: View {
    var entry: ScheduleWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let message = entry.message {
                Text("课表").font(.caption.weight(.semibold)).widgetAccentable()
                Text(message).font(.caption).lineLimit(2)
            } else if let course = entry.focus {
                Text(entry.headline).font(.caption.weight(.semibold)).widgetAccentable().lineLimit(1)
                Text(course.name).font(.headline).lineLimit(1)
                Text([dayPrefixed(course, relativeTo: entry.date), course.room].filter { !$0.isEmpty }.joined(separator: " "))
                    .font(.caption).lineLimit(1)
            } else {
                Text(entry.headline).font(.caption.weight(.semibold)).widgetAccentable()
                Text("暂无课程").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InlineView: View {
    var entry: ScheduleWidgetEntry
    var body: some View {
        if let course = entry.focus, entry.message == nil {
            Label("\(course.name) \(course.beginTime)", systemImage: entry.symbol)
        } else {
            Label(entry.message == nil ? "今天没有课" : "课表未同步", systemImage: "calendar")
        }
    }
}

// MARK: 示例数据（占位 / 预览）

public extension ScheduleWidgetEntry {
    static var sample: ScheduleWidgetEntry {
        let cal = Calendar.current
        let day = cal.startOfDay(for: .now)
        func course(_ name: String, _ room: String, _ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int, dayOffset: Int = 0) -> WidgetCourse {
            let d = cal.date(byAdding: .day, value: dayOffset, to: day)!
            return WidgetCourse.make(
                name: name, room: room,
                startsAt: cal.date(bySettingHour: h1, minute: m1, second: 0, of: d)!,
                endsAt: cal.date(bySettingHour: h2, minute: m2, second: 0, of: d)!
            )
        }
        let now = cal.date(bySettingHour: 10, minute: 20, second: 0, of: day)!
        return ScheduleWidgetEntry(
            date: now, phase: .inClass,
            current: course("高等数学", "西3-406", 10, 0, 11, 40),
            upcoming: [course("大学物理", "东2-201", 14, 30, 16, 5), course("计算机网络", "西1-305", 16, 25, 18, 0)],
            tomorrow: [course("英语", "东1-102", 8, 0, 9, 40, dayOffset: 1)],
            hadClassesToday: true
        )
    }
}
