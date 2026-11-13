import GxuAuth
import GxuStorage
import Observation
import ScheduleKit
import SwiftUI
import UIKit
import WidgetKit

@MainActor
public enum WidgetBridge {
    private static var refreshIDs: [ObjectIdentifier: UUID] = [:]
    private enum RefreshTrigger: Sendable { case foreground, accountChanged }

    public static func run(services: AppServices) async {
        await run(services: services, syncActivity: ClassActivityController.shared.sync)
    }

    static func run(services: AppServices, syncActivity: (NextCourses, Date) async -> Void) async {
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
        await refresh(services: services, now: .now, syncActivity: syncActivity)
        for await trigger in triggers {
            if case .accountChanged = trigger { observeAccount() }
            await refresh(services: services, now: .now, syncActivity: syncActivity)
        }
    }

    public static func refresh(services: AppServices, now: Date = .now) async {
        await refresh(services: services, now: now, syncActivity: ClassActivityController.shared.sync)
    }

    private static func refresh(services: AppServices, now: Date, syncActivity: (NextCourses, Date) async -> Void) async {
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
        let (snapshot, hasClassesToday) = await SnapshotProvider.dailySnapshot(studentId: studentId, database: services.database, unifiedUsername: unifiedUsername, now: now)
        guard !Task.isCancelled, refreshIDs[key] == refreshID, services.accounts.studentId == studentId,
              services.accounts.unifiedUsername == unifiedUsername else { return }
        services.shared.set(snapshot, for: ScheduleKit.widgetSnapshotKey(studentId: studentId))
        services.shared.set(hasClassesToday ? Calendar.current.startOfDay(for: now) : nil, for: WidgetShared.hadClassesDayKey)
        services.shared.set(studentId, for: WidgetShared.activeStudentIdKey)
        WidgetCenter.shared.reloadAllTimelines()
        await syncActivity(snapshot, now)
    }
}

public enum WidgetShared {
    public static let activeStudentIdKey = SharedKey<String>("widget.activeStudentId")
    public static let hadClassesDayKey = SharedKey<Date>("widget.hadClassesDay")

    public static func currentSnapshot(store: any SharedStore) -> NextCourses? {
        guard let studentId = store.value(activeStudentIdKey) else { return nil }
        return store.value(ScheduleKit.widgetSnapshotKey(studentId: studentId))
    }
}

#if DEBUG
extension WidgetBridge {
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
