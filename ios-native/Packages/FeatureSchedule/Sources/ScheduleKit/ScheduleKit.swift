import GxuStorage

/// 无 UI 的课表逻辑（小组件可用）。Phase 0 占位，之后由 Agent B 接管。
public enum ScheduleKit {
    public static let migrations = FeatureMigrations(feature: "schedule") { _ in }
}
