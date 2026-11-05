import ClassWidgetKit
import GxuStorage
import ScheduleKit
import SwiftUI
import WidgetKit

struct ScheduleTimelineEntry: TimelineEntry {
    var content: ScheduleWidgetEntry
    var date: Date { content.date }
}

struct ScheduleProvider: TimelineProvider {
    private func load() -> NextCourses {
        let store = UserDefaultsSharedStore()
        return WidgetShared.currentSnapshot(store: store) ?? .empty(.missingSchedule, now: .now)
    }

    func placeholder(in context: Context) -> ScheduleTimelineEntry { ScheduleTimelineEntry(content: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleTimelineEntry) -> Void) {
        if context.isPreview { return completion(ScheduleTimelineEntry(content: .sample)) }
        completion(ScheduleTimelineEntry(content: ScheduleTimeline.entry(at: .now, snapshot: load())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleTimelineEntry>) -> Void) {
        let (entries, reloadAfter) = ScheduleTimeline.entries(snapshot: load(), now: .now)
        completion(Timeline(entries: entries.map(ScheduleTimelineEntry.init), policy: .after(reloadAfter)))
    }
}

struct ScheduleWidget: Widget {
    static let kind = "com.gxutool.ios.widget.schedule"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetView(entry: entry.content)
        }
        .configurationDisplayName("课表")
        .description("正在上的课和接下来的课。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}
