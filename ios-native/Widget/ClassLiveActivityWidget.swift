import ActivityKit
import ClassWidgetKit
import GxuDesign
import SwiftUI
import WidgetKit

struct ClassLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassActivityAttributes.self) { context in
            LockScreenClassView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(nil)
                .widgetURL(URL(string: "gxutool://schedule"))
        } dynamicIsland: { context in
            let state = context.state
            let stale = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(ClassActivityText.title(state, isStale: stale), systemImage: ClassActivityText.symbol(state, isStale: stale))
                            .font(.caption.weight(.semibold)).foregroundStyle(.tint)
                        Text(state.name).font(.headline).lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(state: state, isStale: stale)
                        .font(.title2.weight(.semibold)).monospacedDigit()
                        .frame(maxWidth: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text([ "\(state.beginText)–\(state.endText)", state.room].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                        ProgressBar(state: state, isStale: stale)
                    }
                }
            } compactLeading: {
                Image(systemName: ClassActivityText.symbol(state, isStale: stale)).foregroundStyle(.tint)
            } compactTrailing: {
                CountdownText(state: state, isStale: stale).monospacedDigit().frame(maxWidth: 48)
            } minimal: {
                Image(systemName: ClassActivityText.symbol(state, isStale: stale)).foregroundStyle(.tint)
            }
            .widgetURL(URL(string: "gxutool://schedule"))
        }
    }
}

/// 界面阶段：开始前 / 上课中 / 已下课。`isStale` 在内容过期点（开始或结束）翻转，系统会重新渲染。
enum ClassActivityPhase { case before, during, ended }

enum ClassActivityText {
    static func phase(_ state: ClassActivityAttributes.ContentState, isStale: Bool, now: Date = .now) -> ClassActivityPhase {
        if now >= state.endsAt { return .ended }
        if now >= state.startsAt { return .during }
        return isStale ? .during : .before
    }

    static func title(_ state: ClassActivityAttributes.ContentState, isStale: Bool) -> String {
        switch phase(state, isStale: isStale) {
        case .before: "即将上课"
        case .during: "正在上课"
        case .ended: "已下课"
        }
    }

    static func symbol(_ state: ClassActivityAttributes.ContentState, isStale: Bool) -> String {
        switch phase(state, isStale: isStale) {
        case .before: "clock"
        case .during: "book.fill"
        case .ended: "checkmark.circle"
        }
    }
}

/// 开始前：距上课；上课中：距下课。用系统计时文字，不需要 App 在后台更新。
private struct CountdownText: View {
    var state: ClassActivityAttributes.ContentState
    var isStale: Bool

    var body: some View {
        let now = Date.now
        switch ClassActivityText.phase(state, isStale: isStale, now: now) {
        case .before: Text(timerInterval: now...max(now, state.startsAt), countsDown: true, showsHours: false)
        case .during: Text(timerInterval: now...max(now, state.endsAt), countsDown: true, showsHours: false)
        case .ended: Text("--:--")
        }
    }
}

private struct ProgressBar: View {
    var state: ClassActivityAttributes.ContentState
    var isStale: Bool

    var body: some View {
        let now = Date.now
        switch ClassActivityText.phase(state, isStale: isStale, now: now) {
        case .before:
            Text("\(state.beginText) 开始").font(.caption).foregroundStyle(.secondary)
        case .during:
            ProgressView(timerInterval: max(state.startsAt, min(now, state.endsAt))...state.endsAt, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(.accentColor)
        case .ended:
            if let following = state.followingName { Text("接下来：\(following)").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct LockScreenClassView: View {
    var state: ClassActivityAttributes.ContentState
    var isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(ClassActivityText.title(state, isStale: isStale), systemImage: ClassActivityText.symbol(state, isStale: isStale))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                Spacer()
                CountdownText(state: state, isStale: isStale)
                    .font(.title3.weight(.semibold)).monospacedDigit()
            }
            Text(state.name).font(.headline).lineLimit(1)
            Text(["\(state.beginText)–\(state.endText)", state.room, state.teacher].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            ProgressBar(state: state, isStale: isStale)
            if let following = state.followingName, let at = state.followingStartsAt, ClassActivityText.phase(state, isStale: isStale) == .during {
                Text("之后：\(following) \(at.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(16)
    }
}
