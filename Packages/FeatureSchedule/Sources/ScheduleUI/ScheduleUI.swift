import GxuFoundation
import GxuStorage
import ScheduleKit
import SwiftUI

public struct ScheduleExtraLayers: Sendable {
    public var exams: [GridExam]
    public var overrides: [OccurrenceOverride]
    public var attendance: [AttendanceMark]

    public init(exams: [GridExam] = [], overrides: [OccurrenceOverride] = [], attendance: [AttendanceMark] = []) {
        self.exams = exams
        self.overrides = overrides
        self.attendance = attendance
    }
}

public typealias ScheduleExtraLayersProvider = @Sendable (_ studentId: String, _ term: AcademicTerm) async -> ScheduleExtraLayers

public enum ScheduleFeature {
    public static var migrations: FeatureMigrations { ScheduleKit.migrations }

    @MainActor
    public static func makeExportView() -> some View { ExportScheduleView() }

    @MainActor
    public static func makeRootView(onRequestLogin: @escaping @MainActor () -> Void = {}, layers: ScheduleExtraLayersProvider? = nil) -> some View {
        ScheduleRootView(onRequestLogin: onRequestLogin, layers: layers)
    }
}


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

public struct ScheduleTeacherSupport: Sendable {
    public struct Info: Sendable, Equatable {
        public var unit: String
        public var avatarURL: URL?
        public init(unit: String = "", avatarURL: URL? = nil) { (self.unit, self.avatarURL) = (unit, avatarURL) }
    }

    public var lookup: @Sendable (String) async -> Info?
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
