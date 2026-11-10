import GxuFoundation
import GxuStorage
import ScheduleKit
import SwiftUI

/// 课表上来自别的模块的额外图层：考试（ExamKit）、实验课对教师 / 地点的覆盖（PEC）。ScheduleKit 不能依赖它们，由 Shell 注入。
public struct ScheduleExtraLayers: Sendable {
    public var exams: [GridExam]
    public var overrides: [OccurrenceOverride]
    /// 考勤记录（FeatureMisc），在课程块上标出这节课的考勤状态
    public var attendance: [AttendanceMark]

    public init(exams: [GridExam] = [], overrides: [OccurrenceOverride] = [], attendance: [AttendanceMark] = []) {
        self.exams = exams
        self.overrides = overrides
        self.attendance = attendance
    }
}

/// 读取某账号某学期的额外图层（只读本地缓存，不联网）
public typealias ScheduleExtraLayersProvider = @Sendable (_ studentId: String, _ term: AcademicTerm) async -> ScheduleExtraLayers

public enum ScheduleFeature {
    public static var migrations: FeatureMigrations { ScheduleKit.migrations }

    /// 工具箱 →「导出课表」
    @MainActor
    public static func makeExportView() -> some View { ExportScheduleView() }

    /// - Parameter onRequestLogin: 未登录时空状态里的“去登录”按钮
    @MainActor
    public static func makeRootView(onRequestLogin: @escaping @MainActor () -> Void = {}, layers: ScheduleExtraLayersProvider? = nil) -> some View {
        ScheduleRootView(onRequestLogin: onRequestLogin, layers: layers)
    }
}


/// 课程详情“导航到这里”：把地点交给 Shell 解析（楼名数据在 FeatureCampus，ScheduleUI 不依赖它），Shell 返回要怎么做（RN `useMapNavigation.openMap`）：
/// 解析不到 → 提示；没有地图应用 → 提示；一个 → 直接打开；多个 → 让用户选。没有注入时不显示按钮。
public typealias ScheduleMapPlanProvider = @MainActor @Sendable (CourseNavigation.Target) -> MapOpenPlan

private struct ScheduleMapPlanKey: EnvironmentKey {
    static let defaultValue: ScheduleMapPlanProvider? = nil
}

public extension EnvironmentValues {
    var scheduleMapPlan: ScheduleMapPlanProvider? {
        get { self[ScheduleMapPlanKey.self] }
        set { self[ScheduleMapPlanKey.self] = newValue }
    }
}

/// 课程详情“任课教师”卡片（RN `CourseDetailSheet`）：头像 + 姓名 + 单位 + “查看详情”。
/// 教师数据在 FeatureMisc（会依赖本 package），所以由 Shell 注入；没有注入时卡片不显示，教师仍作为普通一行展示。
public struct ScheduleTeacherSupport: Sendable {
    public struct Info: Sendable, Equatable {
        public var unit: String
        public var avatarURL: URL?
        public init(unit: String = "", avatarURL: URL? = nil) { (self.unit, self.avatarURL) = (unit, avatarURL) }
    }

    /// 按教师姓名查（RN `useLookup`），取第一条；查不到返回 nil（卡片仍显示姓名和默认头像）
    public var lookup: @Sendable (String) async -> Info?
    /// “查看详情”进入的页面（教师查询）
    public var destination: @MainActor @Sendable (String) -> AnyView

    public init(lookup: @escaping @Sendable (String) async -> Info?, destination: @escaping @MainActor @Sendable (String) -> AnyView) {
        self.lookup = lookup
        self.destination = destination
    }
}

private struct ScheduleTeacherSupportKey: EnvironmentKey {
    static let defaultValue: ScheduleTeacherSupport? = nil
}

public extension EnvironmentValues {
    var scheduleTeacherSupport: ScheduleTeacherSupport? {
        get { self[ScheduleTeacherSupportKey.self] }
        set { self[ScheduleTeacherSupportKey.self] = newValue }
    }
}
