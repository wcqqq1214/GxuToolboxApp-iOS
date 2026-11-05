import ExamUI
import FeatureAccount
import FeatureCampus
import FeatureCourse
import FeatureMisc
import ScheduleUI
import SwiftUI

struct ToolboxItem: Identifiable {
    /// 分组和名称以 RN 的 `ToolboxIndex.tsx` 为准
    enum Section: String, CaseIterable, Identifiable {
        case info = "信息查询"
        case practice = "实践课"
        case notice = "通知"
        case evaluation = "教学评价"
        case other = "其他"
        var id: String { rawValue }
    }

    enum Action {
        /// 推入一个页面
        case push(@MainActor () -> AnyView)
        /// 切到某个标签页（如“课表”）
        case tab(AppTab)
    }

    let id: String
    let title: String
    let systemImage: String
    let section: Section
    /// nil = 即将上线
    let action: Action?

    var isAvailable: Bool { action != nil }

    /// `.push` 的目标页面
    @MainActor var pushedView: AnyView? {
        if case .push(let make)? = action { return make() }
        return nil
    }
}

/// 工具箱里的全部功能：**功能和分组以 RN 为准，不要新加**（用户原则）。每个功能一行；
/// 各 Agent 上线时把自己那一行最后的参数从 nil 换成 `.push { AnyView(XxxView()) }`。
/// RN 里没有入口或需要后端代理才能做的项目（调课信息、选课课程列表）暂时不放，等后端接口后加回原来的位置。
enum ToolboxCatalog {
    private static func item(
        _ id: String, _ title: String, _ systemImage: String, _ section: ToolboxItem.Section,
        _ action: ToolboxItem.Action? = nil
    ) -> ToolboxItem {
        ToolboxItem(id: id, title: title, systemImage: systemImage, section: section, action: action)
    }

    static let items: [ToolboxItem] = [
        // 信息查询
        item("schedule", "课表", "calendar", .info, .tab(.schedule)),
        item("classSchedule", "班级课表", "person.3", .info, .push { AnyView(CampusFeature.makeClassScheduleView()) }),
        item("exportSchedule", "导出课表", "square.and.arrow.up", .info, .push { AnyView(ScheduleFeature.makeExportView()) }),
        item("examInfo", "考试考场", "building.2", .info, .push { AnyView(ExamInfoView()) }),
        item("examScore", "考试成绩", "chart.bar.doc.horizontal", .info, .push { AnyView(ScoreWithPendingView()) }),
        item("attendance", "考勤信息", "person.badge.clock", .info, .push { AnyView(AttendanceView()) }),
        item("electiveStrategy", "校选课查漏", "checklist", .info, .push { AnyView(ElectiveStrategyView()) }),
        item("teacherInfo", "教师信息查询", "person.text.rectangle", .info),
        // 实践课
        item("phyExp", "物理实验课", "atom", .practice),
        item("engTraining", "金工实训", "wrench.and.screwdriver", .practice),
        // 通知
        item("timeShift", "调休信息", "calendar.badge.exclamationmark", .notice, .push { AnyView(TimeShiftView()) }),
        item("holiday", "法定节假日", "sun.max", .notice, .push { AnyView(HolidayView()) }),
        item("oaFiles", "学校文件", "doc.text", .notice, .push { AnyView(AccountFeature.makeOAFilesView()) }),
        // 教学评价
        item("evaluation", "期末学生评价", "text.badge.checkmark", .evaluation),
        // 其他
        item("campusMap", "地图导航", "map", .other),
        item("fullSchedule", "全校实时课表", "building.columns", .other, .push { AnyView(CampusFeature.makeFullScheduleView()) }),
        item("floorPlan", "教学楼平面图", "building.2.crop.circle", .other),
    ]
}
