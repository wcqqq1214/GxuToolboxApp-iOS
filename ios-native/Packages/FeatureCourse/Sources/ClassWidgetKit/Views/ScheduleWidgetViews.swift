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

    /// 上课中显示距下课，等待中显示距上课。用系统动态时间样式，不需要时间线刷新
    private var relative: (date: Date, suffix: String)? {
        if let current = entry.current { return (current.endsAt, "后下课") }
        if entry.phase == .waiting, let first = entry.upcoming.first { return (first.startsAt, "后上课") }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            StatusLabel(entry: entry)
            if let relative {
                Spacer(minLength: 2)
                VStack(alignment: .leading, spacing: 0) {
                    Text(relative.date, style: .relative)
                        .font(.title2.weight(.semibold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .environment(\.locale, Locale(identifier: "zh_CN"))   // 固定中文单位：25分钟
                    Text(relative.suffix).font(.caption).foregroundStyle(.secondary)
                }
                .widgetAccentable()
            }
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
            VStack(alignment: .leading, spacing: 0) {
                Text(course.name).font(.subheadline.weight(highlighted ? .semibold : .regular)).lineLimit(1)
                Text([showsDay ? dayPrefixed(course, relativeTo: date) : timeRange(course), course.room].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            if highlighted {
                Spacer(minLength: 4)
                Text("上课中").font(.caption2.weight(.semibold)).foregroundStyle(.tint)
            }
        }
        .padding(highlighted ? 6 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if highlighted {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.14)).widgetAccentable()
            }
        }
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

    /// 固定中文格式，不随系统语言变化：11月5日 周四
    static func dateText(_ date: Date) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)月\(c.day ?? 0)日 " + WeekdayName.full((cal.component(.weekday, from: date) + 5) % 7 + 1)
    }

    private var today: [WidgetCourse] { [entry.current].compactMap { $0 } + entry.upcoming }

    var body: some View {
        if entry.message != nil {
            MessageView(entry: entry)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StatusLabel(entry: entry)
                    Spacer()
                    Text(Self.dateText(entry.date))
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
    /// 占位 / 预览数据：时间相对"现在"，这样动态的相对时间文字看起来是对的
    static var sample: ScheduleWidgetEntry {
        let cal = Calendar.current
        let now = Date.now
        func course(_ name: String, _ room: String, from start: TimeInterval, minutes: Double = 100) -> WidgetCourse {
            WidgetCourse.make(name: name, room: room, startsAt: now.addingTimeInterval(start), endsAt: now.addingTimeInterval(start + minutes * 60))
        }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        func tomorrowCourse(_ name: String, _ room: String, hour: Int) -> WidgetCourse {
            WidgetCourse.make(name: name, room: room, startsAt: cal.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow)!, endsAt: cal.date(bySettingHour: hour + 1, minute: 40, second: 0, of: tomorrow)!)
        }
        return ScheduleWidgetEntry(
            date: now, phase: .inClass,
            current: course("高等数学", "西3-406", from: -25 * 60),
            upcoming: [course("大学物理", "东2-201", from: 3 * 3600), course("计算机网络", "西1-305", from: 5 * 3600)],
            tomorrow: [tomorrowCourse("英语", "东1-102", hour: 8)],
            hadClassesToday: true
        )
    }
}
