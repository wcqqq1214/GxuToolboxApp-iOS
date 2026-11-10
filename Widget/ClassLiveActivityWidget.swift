import ActivityKit
import ClassWidgetKit
import GxuDesign
import SwiftUI
import WidgetKit

struct ClassLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassActivityAttributes.self) { context in
            LockScreenClassView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
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
                    ClassCountdownText(state: state, isStale: stale)
                        .font(.title2.weight(.semibold)).monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text([ "\(state.beginText)–\(state.endText)", state.room].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                        ClassProgressBar(state: state, isStale: stale)
                    }
                }
            } compactLeading: {
                Image(systemName: ClassActivityText.symbol(state, isStale: stale)).foregroundStyle(.tint)
            } compactTrailing: {
                ClassCountdownText(state: state, isStale: stale)
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48, alignment: .trailing)
            } minimal: {
                Image(systemName: ClassActivityText.symbol(state, isStale: stale)).foregroundStyle(.tint)
            }
            .widgetURL(URL(string: "gxutool://schedule"))
        }
    }
}

