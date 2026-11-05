import SwiftUI
import WidgetKit

/// Phase 0 占位。Widget 目录从此归 Agent C 所有。
struct PlaceholderEntry: TimelineEntry { let date: Date }

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) { completion(.init(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .never))
    }
}

struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "placeholder", provider: PlaceholderProvider()) { _ in
            Text("西大工具箱").containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("西大工具箱")
        .description("占位")
    }
}

@main
struct GxuWidgetBundle: WidgetBundle {
    var body: some Widget { PlaceholderWidget() }
}
