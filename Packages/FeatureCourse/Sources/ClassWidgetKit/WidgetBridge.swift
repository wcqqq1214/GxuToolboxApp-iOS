import GxuAuth
import GxuStorage
import Observation
import ScheduleKit
import SwiftUI
import UIKit
import WidgetKit

/// App ↔ 小组件 / Live Activity 的桥。App 在根视图上挂一次：
///
///     RootView().task { await WidgetBridge.run(services: services) }
///
/// 每次进入前台、账号变化时：从本地缓存重新算快照写入 App Group → 刷新小组件时间线 → 同步 Live Activity。
@MainActor
public enum WidgetBridge {
    private static var refreshIDs: [ObjectIdentifier: UUID] = [:]
    private enum RefreshTrigger: Sendable { case foreground, accountChanged }

    /// 运行直到任务取消。
    public static func run(services: AppServices) async {
        #if DEBUG
        if let directory = WidgetGallery.outputDirectory() { WidgetGallery.run(into: directory); return }
        if ProcessInfo.processInfo.arguments.contains("-GxuWidgetDemo") { await runDemo(services: services); return }
        #endif
        let (triggers, continuation) = AsyncStream<RefreshTrigger>.makeStream()
        let foreground = Task {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                continuation.yield(.foreground)
            }
        }
        defer {
            foreground.cancel()
            continuation.finish()
        }
        func observeAccount() {
            withObservationTracking {
                _ = services.accounts.studentId
                _ = services.accounts.unifiedUsername
            } onChange: {
                continuation.yield(.accountChanged)
            }
        }

        observeAccount()
        await refresh(services: services)
        for await trigger in triggers {
            if case .accountChanged = trigger { observeAccount() }
            await refresh(services: services)
        }
    }

    public static func refresh(services: AppServices, now: Date = .now) async {
        guard !Task.isCancelled else { return }
        let key = ObjectIdentifier(services.accounts)
        let refreshID = UUID()
        refreshIDs[key] = refreshID
        defer { if refreshIDs[key] == refreshID { refreshIDs[key] = nil } }
        if services.shared.value(WidgetShared.activeStudentIdKey) != services.accounts.studentId {
            services.shared.set(nil, for: WidgetShared.activeStudentIdKey)
            services.shared.set(nil, for: WidgetShared.hadClassesDayKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
        guard let studentId = services.accounts.studentId else {
            await ClassActivityController.shared.endAll()
            return
        }
        let unifiedUsername = services.accounts.unifiedUsername
        let snapshot = await SnapshotProvider.compute(studentId: studentId, database: services.database, unifiedUsername: unifiedUsername, now: now)
        // 最后一节课结束后刷新时 `today` 为空，另记一笔"今天有过课"，小组件才能写"今天的课已上完"
        var had = !snapshot.today.isEmpty
        if !had { had = await SnapshotProvider.hadClasses(on: now, studentId: studentId, database: services.database, unifiedUsername: unifiedUsername) }
        guard !Task.isCancelled, refreshIDs[key] == refreshID, services.accounts.studentId == studentId,
              services.accounts.unifiedUsername == unifiedUsername else { return }
        services.shared.set(snapshot, for: ScheduleKit.widgetSnapshotKey(studentId: studentId))
        services.shared.set(had ? Calendar.current.startOfDay(for: now) : nil, for: WidgetShared.hadClassesDayKey)
        services.shared.set(studentId, for: WidgetShared.activeStudentIdKey)
        WidgetCenter.shared.reloadAllTimelines()
        await ClassActivityController.shared.sync(snapshot: snapshot, now: now)
    }
}

public enum WidgetShared {
    /// 小组件扩展不依赖 Keychain 就能知道该读哪个学号的快照
    public static let activeStudentIdKey = SharedKey<String>("widget.activeStudentId")
    /// 刷新快照时发现"这一天有过课"，值是那天的 00:00（只对那一天有效）
    public static let hadClassesDayKey = SharedKey<Date>("widget.hadClassesDay")

    /// 读当前账号的快照；没有账号或没有快照返回 nil
    public static func currentSnapshot(store: any SharedStore) -> NextCourses? {
        guard let studentId = store.value(activeStudentIdKey) else { return nil }
        return store.value(ScheduleKit.widgetSnapshotKey(studentId: studentId))
    }
}

#if DEBUG
extension WidgetBridge {
    /// `-GxuWidgetDemo`：不依赖账号和网络，写一份"此刻正在上课"的演示快照，供小组件 / 灵动岛截图自查
    static func runDemo(services: AppServices) async {
        let cal = Calendar.current
        let now = Date.now
        func course(_ name: String, _ room: String, _ teacher: String, from start: TimeInterval, length: TimeInterval) -> WidgetCourse {
            WidgetCourse.make(name: name, room: room, teacher: teacher, startsAt: now.addingTimeInterval(start), endsAt: now.addingTimeInterval(start + length))
        }
        let tomorrowStart = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        let tomorrow = [
            WidgetCourse.make(name: "英语", room: "东1-102", startsAt: tomorrowStart.addingTimeInterval(8 * 3600), endsAt: tomorrowStart.addingTimeInterval(9 * 3600 + 40 * 60)),
            WidgetCourse.make(name: "数据结构", room: "西3-406", startsAt: tomorrowStart.addingTimeInterval(10 * 3600), endsAt: tomorrowStart.addingTimeInterval(11 * 3600 + 40 * 60)),
        ]
        let today = [
            course("高等数学", "西3-406", "张老师", from: -25 * 60, length: 100 * 60),
            course("大学物理", "东2-201", "李老师", from: 3 * 3600, length: 100 * 60),
            course("计算机网络", "西1-305", "王老师", from: 5 * 3600, length: 100 * 60),
        ]
        let snapshot = NextCourses.make(today: today, tomorrow: tomorrow, next: today[1], refreshedAt: now)
        services.shared.set("demo", for: WidgetShared.activeStudentIdKey)
        services.shared.set(snapshot, for: ScheduleKit.widgetSnapshotKey(studentId: "demo"))
        WidgetCenter.shared.reloadAllTimelines()
        await ClassActivityController.shared.sync(snapshot: snapshot, now: now)
    }
}
#endif
