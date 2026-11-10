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
    /// 仅设计自查：ImageRenderer 渲不了 `ProgressView(timerInterval:)`，截图时改用静态进度
    var previewProgress: Double?

    public init(state: ClassActivityAttributes.ContentState, isStale: Bool, previewProgress: Double? = nil) {
        self.state = state
        self.isStale = isStale
        self.previewProgress = previewProgress
    }

    public var body: some View {
        let now = Date.now
        switch ClassActivityText.phase(state, isStale: isStale, now: now) {
        case .before:
            EmptyView()   // 开始时间已在时间段里，倒计时也在右上角：不再单独写"HH:mm 开始"
        case .during:
            if let previewProgress {
                // ImageRenderer 连 ProgressView 本身都渲不出来（显示占位符），自查截图用手绘的静态条
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.3))
                    Capsule().fill(Color.accentColor).scaleEffect(x: previewProgress, anchor: .leading)
                }
                .frame(height: 4)
            } else {
                ProgressView(timerInterval: state.startsAt...state.endsAt, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(.accentColor)
            }
        case .ended:
            if let following = state.followingName { Text("接下来：\(following)").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

public struct LockScreenClassView: View {
    var state: ClassActivityAttributes.ContentState
    var isStale: Bool
    var previewProgress: Double?

    public init(state: ClassActivityAttributes.ContentState, isStale: Bool, previewProgress: Double? = nil) {
        self.state = state
        self.isStale = isStale
        self.previewProgress = previewProgress
    }

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
                    .multilineTextAlignment(.trailing)
            }
            Text(state.name).font(.headline).lineLimit(1)
            Text(["\(state.beginText)–\(state.endText)", state.room, state.teacher].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            ClassProgressBar(state: state, isStale: isStale, previewProgress: previewProgress)
            if let following = state.followingName, let at = state.followingStartsAt, ClassActivityText.phase(state, isStale: isStale) == .during {
                Text("之后 \(Self.hm(at)) \(following)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(16)
    }
}
