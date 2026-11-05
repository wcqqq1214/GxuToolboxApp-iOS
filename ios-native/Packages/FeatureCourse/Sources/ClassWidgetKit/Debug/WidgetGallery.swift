#if DEBUG
import ActivityKit
import Foundation
import ScheduleKit
import SwiftUI
import WidgetKit

/// DEBUG 设计自查：把小组件和 Live Activity 视图按真实点尺寸渲染成 PNG。
/// 启动参数 `-GxuWidgetGallery <输出目录>`。系统的 accented 合成（染色、去色）无法在进程内复现，
/// 这里的 accented 图是去色近似，只用来检查层级和对比；真实效果要在设备上确认。
@MainActor
enum WidgetGallery {
    static func outputDirectory() -> URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-GxuWidgetGallery"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1], isDirectory: true)
    }

    enum Look: String, CaseIterable { case light, dark, accented }

    static func run(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sample = ScheduleWidgetEntry.sample
        let waiting = ScheduleWidgetEntry(date: sample.date, phase: .waiting, upcoming: sample.upcoming, tomorrow: sample.tomorrow, next: sample.upcoming.first, hadClassesToday: true)
        let finished = ScheduleWidgetEntry(date: sample.date, phase: .finished, tomorrow: sample.tomorrow, next: sample.tomorrow.first, hadClassesToday: true)
        let unavailable = ScheduleWidgetEntry(date: sample.date, phase: .unavailable(.missingSchedule))

        let families: [(String, WidgetFamily, CGSize)] = [
            ("small", .systemSmall, CGSize(width: 170, height: 170)),
            ("medium", .systemMedium, CGSize(width: 364, height: 170)),
            ("large", .systemLarge, CGSize(width: 364, height: 382)),
            ("rectangular", .accessoryRectangular, CGSize(width: 172, height: 76)),
            ("inline", .accessoryInline, CGSize(width: 257, height: 26)),
        ]
        for look in Look.allCases {
            for (name, family, size) in families {
                save(widget(sample, family: family, size: size, look: look), "widget-\(name)-inclass-\(look.rawValue)", directory)
            }
        }
        for look in [Look.light, .dark] {
            for (label, entry) in [("waiting", waiting), ("finished", finished), ("unavailable", unavailable)] {
                save(widget(entry, family: .systemSmall, size: CGSize(width: 170, height: 170), look: look), "widget-small-\(label)-\(look.rawValue)", directory)
                save(widget(entry, family: .accessoryRectangular, size: CGSize(width: 172, height: 76), look: look), "widget-rectangular-\(label)-\(look.rawValue)", directory)
            }
        }
        liveActivity(into: directory)
    }

    private static func widget(_ entry: ScheduleWidgetEntry, family: WidgetFamily, size: CGSize, look: Look) -> some View {
        let lock = family == .accessoryRectangular || family == .accessoryInline
        let scheme: ColorScheme = look == .light ? .light : .dark
        return ZStack {
            if lock {
                LinearGradient(colors: [Color(red: 0.16, green: 0.2, blue: 0.35), Color(red: 0.05, green: 0.06, blue: 0.12)], startPoint: .top, endPoint: .bottom)
            } else {
                (look == .light ? Color(red: 0.95, green: 0.95, blue: 0.97) : Color(red: 0.11, green: 0.11, blue: 0.12))
            }
            ScheduleWidgetView(entry: entry, family: family)
                .padding(lock ? 8 : 16)
                .foregroundStyle(lock ? Color.white : Color.primary)
                .modifier(AccentedApproximation(enabled: look == .accented))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: lock ? 12 : 22, style: .continuous))
        .environment(\.colorScheme, lock ? .dark : scheme)
        .tint(Color(red: 0.0, green: 0.48, blue: 1.0))
    }

    private struct AccentedApproximation: ViewModifier {
        var enabled: Bool
        func body(content: Content) -> some View {
            if enabled { content.saturation(0).colorMultiply(Color(white: 0.92)) } else { content }
        }
    }

    // MARK: Live Activity / 灵动岛

    private static func state(startOffset: TimeInterval, length: TimeInterval = 100 * 60, following: Bool = true) -> ClassActivityAttributes.ContentState {
        let now = Date.now
        let course = WidgetCourse.make(name: "高等数学", room: "西3-406", teacher: "张老师", startsAt: now.addingTimeInterval(startOffset), endsAt: now.addingTimeInterval(startOffset + length))
        let next = WidgetCourse.make(name: "大学物理", room: "东2-201", startsAt: now.addingTimeInterval(startOffset + length + 20 * 60), endsAt: now.addingTimeInterval(startOffset + 2 * length + 20 * 60))
        return .init(course, following: following ? next : nil)
    }

    private static func liveActivity(into directory: URL) {
        let during = state(startOffset: -25 * 60)
        let before = state(startOffset: 12 * 60)
        for scheme in [ColorScheme.light, .dark] {
            for (label, st, stale) in [("during", during, false), ("before", before, false)] {
                let view = LockScreenClassView(state: st, isStale: stale, previewProgress: 0.25)
                    .frame(width: 364)
                    .background(scheme == .dark ? Color(white: 0.14) : Color(white: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .environment(\.colorScheme, scheme)
                    .tint(.blue)
                save(view, "activity-lock-\(label)-\(scheme == .dark ? "dark" : "light")", directory)
            }
        }
        // 灵动岛始终是黑底
        for (label, st) in [("during", during), ("before", before)] {
            save(island(compact: st), "island-compact-\(label)", directory)
            save(island(minimal: st), "island-minimal-\(label)", directory)
            save(island(expanded: st), "island-expanded-\(label)", directory)
        }
    }

    private static func islandShell<C: View>(width: CGFloat, height: CGFloat, radius: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(width: width, height: height)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .environment(\.colorScheme, .dark)
            .tint(.blue)
            .padding(8)
            .background(Color(white: 0.3))
    }

    private static func island(compact st: ClassActivityAttributes.ContentState) -> some View {
        islandShell(width: 230, height: 37, radius: 18.5) {
            HStack {
                Image(systemName: ClassActivityText.symbol(st, isStale: false)).foregroundStyle(.tint)
                Spacer()
                ClassCountdownText(state: st, isStale: false).monospacedDigit().frame(maxWidth: 48)
            }
            .padding(.horizontal, 14)
        }
    }

    private static func island(minimal st: ClassActivityAttributes.ContentState) -> some View {
        islandShell(width: 37, height: 37, radius: 18.5) {
            Image(systemName: ClassActivityText.symbol(st, isStale: false)).foregroundStyle(.tint)
        }
    }

    private static func island(expanded st: ClassActivityAttributes.ContentState) -> some View {
        islandShell(width: 371, height: 168, radius: 44) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(ClassActivityText.title(st, isStale: false), systemImage: ClassActivityText.symbol(st, isStale: false))
                            .font(.caption.weight(.semibold)).foregroundStyle(.tint)
                        Text(st.name).font(.headline).lineLimit(2)
                    }
                    Spacer()
                    ClassCountdownText(state: st, isStale: false).font(.title2.weight(.semibold)).monospacedDigit()
                        .frame(maxWidth: 80, alignment: .trailing)
                }
                Text(["\(st.beginText)–\(st.endText)", st.room].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
                ClassProgressBar(state: st, isStale: false, previewProgress: 0.25)
            }
            .padding(.horizontal, 22).padding(.top, 36).padding(.bottom, 14)
        }
    }

    private static func save<V: View>(_ view: V, _ name: String, _ directory: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { return }
        try? data.write(to: directory.appending(path: "\(name).png"))
    }
}
#endif
