import ExamKit
import GxuDesign
import ScheduleKit
import SwiftUI

/// 标签栏上方的“下一节课”附件。内容层只放文字和图标，玻璃由系统附件容器提供。
struct NextEventAccessory: View {
    let model: HomeModel
    @Environment(\.gxuAccessoryCompact) private var compact

    var body: some View {
        // 每分钟重算一次相对时间，也会在上课 / 下课的整分更新“还剩 / 之后”
        TimelineView(.everyMinute) { context in
            let now = context.date
            if let snapshot = model.snapshot,
               let event = HomeEvent.pick(snapshot: snapshot, exams: model.exams, now: now) {
                row(event, now: now)
            }
        }
        .padding(.horizontal, GxuDesign.Spacing.l)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func row(_ event: HomeEvent, now: Date) -> some View {
        HStack(spacing: GxuDesign.Spacing.m) {
            Image(systemName: icon(event)).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(title(event)).font(.subheadline.weight(.semibold)).lineLimit(1)
                if !compact { Text(detail(event, now: now)).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer(minLength: GxuDesign.Spacing.s)
            Text(trailing(event, now: now))
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(event.isOngoing ? Color.green : .secondary)
                .lineLimit(1)
        }
    }

    private func icon(_ event: HomeEvent) -> String {
        switch event {
        case .course: event.isOngoing ? "book.fill" : "book"
        case .exam: "pencil.and.list.clipboard"
        case .holiday: "sun.max"
        }
    }

    private func title(_ event: HomeEvent) -> String {
        switch event {
        case .course(let item, _, _): item.course.courseName
        case .exam(let item, _): "考试 · \(item.exam.course)"
        case .holiday(let holiday): "下个假期 · \(holiday.title)"
        }
    }

    private func detail(_ event: HomeEvent, now: Date) -> String {
        switch event {
        // 右侧已经写了具体时刻时（“明天 09:00”），左侧不再重复时间
        case .course(let item, _, _):
            [RelativeTime.showsClock(in: trailing(event, now: now)) ? "" : item.timeRangeText, item.course.venueName]
                .filter { !$0.isEmpty }.joined(separator: " · ")
        case .exam(let item, _):
            [item.exam.classroom, item.exam.seatText].filter { !$0.isEmpty }.joined(separator: " · ")
        case .holiday: ""
        }
    }

    private func trailing(_ event: HomeEvent, now: Date) -> String {
        switch event {
        case .course(let item, true, _): RelativeTime.remaining(until: item.endsAt, now: now)
        case .exam: event.isOngoing ? "进行中" : RelativeTime.untilStart(event.startsAt, now: now)
        case .holiday(let holiday): holiday.dayText(now: now, calendar: .current)
        case .course: RelativeTime.untilStart(event.startsAt, now: now)
        }
    }
}
