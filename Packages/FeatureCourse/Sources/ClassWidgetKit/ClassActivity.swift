import ActivityKit
import Foundation
import ScheduleKit

/// Live Activity / 灵动岛：显示正在上的课，或即将开始的下一节课。
public struct ClassActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var courseId: String
        public var name: String
        public var room: String
        public var teacher: String
        /// `HH:mm`
        public var beginText: String
        public var endText: String
        public var startsAt: Date
        public var endsAt: Date
        /// 这节之后的下一节（同一天），没有则为 nil
        public var followingName: String?
        public var followingStartsAt: Date?

        public init(_ course: WidgetCourse, following: WidgetCourse?) {
            courseId = course.id
            name = course.name
            room = course.room
            teacher = course.teacher
            beginText = course.beginTime
            endText = course.endTime
            startsAt = course.startsAt
            endsAt = course.endsAt
            followingName = following?.name
            followingStartsAt = following?.startsAt
        }

        public func isInClass(at date: Date) -> Bool { startsAt <= date && date < endsAt }
    }

    public init() {}
}

/// 决定此刻要不要显示 Live Activity、显示哪一节。纯逻辑，便于测试。
public struct ClassActivityPlan: Equatable, Sendable {
    public var state: ClassActivityAttributes.ContentState
    /// 到这个时间点内容会过期：开始前过期后界面切换成"上课中"，上课中过期后切换成"已下课"
    public var staleDate: Date

    public static func make(
        snapshot: NextCourses, now: Date, leadTime: TimeInterval = 60 * 60, calendar: Calendar = .current
    ) -> ClassActivityPlan? {
        guard snapshot.state == .ready else { return nil }
        let today = snapshot.today.sorted { $0.startsAt < $1.startsAt }
        let target: WidgetCourse
        if let current = today.first(where: { $0.startsAt <= now && now < $0.endsAt }) {
            target = current
        } else if let soon = today.first(where: { $0.startsAt > now && $0.startsAt.timeIntervalSince(now) <= leadTime }) {
            target = soon
        } else {
            return nil
        }
        let following = today.first { $0.startsAt >= target.endsAt }
        let isCurrent = target.startsAt <= now
        return ClassActivityPlan(
            state: .init(target, following: following),
            staleDate: isCurrent ? target.endsAt : target.startsAt
        )
    }
}

/// App 侧：按快照开始 / 更新 / 结束 Live Activity。只在前台调用（回前台、课表刷新后）。
/// Activity 不是 Sendable，所以这里不绑 MainActor：每个方法在自己的执行上下文里取 / 用 activity。
public struct ClassActivityController: Sendable {
    public static let shared = ClassActivityController()

    public func sync(snapshot: NextCourses, now: Date = .now) async {
        let plan = ClassActivityPlan.make(snapshot: snapshot, now: now)
        let activities = Activity<ClassActivityAttributes>.activities

        guard let plan else {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let content = ActivityContent(state: plan.state, staleDate: plan.staleDate)

        if let existing = activities.first(where: { $0.content.state.courseId == plan.state.courseId }) {
            await existing.update(content)
            for other in activities where other.id != existing.id { await other.end(nil, dismissalPolicy: .immediate) }
            return
        }
        for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(attributes: ClassActivityAttributes(), content: content)
    }

    public func endAll() async {
        for activity in Activity<ClassActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
