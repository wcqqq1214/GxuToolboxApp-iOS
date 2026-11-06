import GxuFoundation
import GxuStorage
import ScheduleKit
import SwiftUI

/// 课表上来自别的模块的额外图层：考试（ExamKit）、实验课对教师 / 地点的覆盖（PEC）。ScheduleKit 不能依赖它们，由 Shell 注入。
public struct ScheduleExtraLayers: Sendable {
    public var exams: [GridExam]
    public var overrides: [OccurrenceOverride]

    public init(exams: [GridExam] = [], overrides: [OccurrenceOverride] = []) {
        self.exams = exams
        self.overrides = overrides
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
