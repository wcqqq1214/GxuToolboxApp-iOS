import AppIntents
import ToolboxIntents

struct GxuIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [ToolboxIntentsPackage.self] }
}

struct GxuAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodayCoursesIntent(),
            phrases: ["\(.applicationName)今天的课", "用\(.applicationName)查今天有什么课"],
            shortTitle: "今天的课", systemImageName: "calendar"
        )
        AppShortcut(
            intent: TomorrowCoursesIntent(),
            phrases: ["\(.applicationName)明天的课", "用\(.applicationName)查明天有什么课"],
            shortTitle: "明天的课", systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: NextExamIntent(),
            phrases: ["\(.applicationName)下一场考试", "用\(.applicationName)查下一场考试"],
            shortTitle: "下一场考试", systemImageName: "pencil.and.list.clipboard"
        )
    }
}
