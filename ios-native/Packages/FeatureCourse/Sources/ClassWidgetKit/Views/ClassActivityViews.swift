import ActivityKit
import SwiftUI

/// 界面阶段：开始前 / 上课中 / 已下课。`isStale` 在内容过期点（开始或结束）翻转，系统会重新渲染。
public enum ClassActivityPhase { case before, during, ended }

public enum ClassActivityText {
    public static func phase(_ state: ClassActivityAttributes.ContentState, isStale: Bool, now: Date = .now) -> ClassActivityPhase {
        if now >= state.endsAt { return .ended }
        if now >= state.startsAt { return .during }
        return isStale ? .during : .before
    }

    public static func title(_ state: ClassActivityAttributes.ContentState, isStale: Bool) -> String {
        switch phase(state, isStale: isStale) {
        case .before: "即将上课"
        case .during: "正在上课"
        case .ended: "已下课"
        }
    }

    public static func symbol(_ state: ClassActivityAttributes.ContentState, isStale: Bool) -> String {
        switch phase(state, isStale: isStale) {
        case .before: "clock"
        case .during: "book.fill"
        case .ended: "checkmark.circle"
        }
    }
}

/// 开始前：距上课；上课中：距下课。用系统计时文字，不需要 App 在后台更新。
public struct ClassCountdownText: View {
    var state: ClassActivityAttributes.ContentState
    var isStale: Bool

    public init(state: ClassActivityAttributes.ContentState, isStale: Bool) { self.state = state; self.isStale = isStale }

    public var body: some View {
        let now = Date.now
        switch ClassActivityText.phase(state, isStale: isStale, now: now) {
        case .before: Text(timerInterval: now...max(now, state.startsAt), countsDown: true, showsHours: false)
        case .during: Text(timerInterval: now...max(now, state.endsAt), countsDown: true, showsHours: false)
        case .ended: Text("--:--")
        }
    }
}

public struct ClassProgressBar: View {
    var state: ClassActivityAttributes.ContentState
    var isStale: Bool

    public init(state: ClassActivityAttributes.ContentState, isStale: Bool) { self.state = state; self.isStale = isStale }

    public var body: some View {
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

public struct LockScreenClassView: View {
    var state: ClassActivityAttributes.ContentState
    var isStale: Bool

    public init(state: ClassActivityAttributes.ContentState, isStale: Bool) { self.state = state; self.isStale = isStale }

    private static func hm(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(ClassActivityText.title(state, isStale: isStale), systemImage: ClassActivityText.symbol(state, isStale: isStale))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                Spacer()
                ClassCountdownText(state: state, isStale: isStale)
                    .font(.title3.weight(.semibold)).monospacedDigit()
            }
            Text(state.name).font(.headline).lineLimit(1)
            Text(["\(state.beginText)–\(state.endText)", state.room, state.teacher].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            ClassProgressBar(state: state, isStale: isStale)
            if let following = state.followingName, let at = state.followingStartsAt, ClassActivityText.phase(state, isStale: isStale) == .during {
                Text("之后：\(following) \(Self.hm(at))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(16)
    }
}
