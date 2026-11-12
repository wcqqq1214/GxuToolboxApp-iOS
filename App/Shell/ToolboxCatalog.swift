import ExamUI
import FeatureAccount
import FeatureCampus
import FeatureCourse
import FeatureMisc
import ScheduleUI
import SwiftUI

struct ToolboxItem: Identifiable {
    enum Section: String, CaseIterable, Identifiable {
        case info = "信息查询"
        case practice = "实践课"
        case notice = "通知"
        case evaluation = "教学评价"
        case other = "其他"
        var id: String { rawValue }
    }

    enum Action {
        case push(@MainActor () -> AnyView)
        case tab(AppTab)
    }

    let id: String
    let title: String
    let systemImage: String
    let section: Section
    let action: Action?

    var isAvailable: Bool { action != nil }

    @MainActor var pushedView: AnyView? {
        if case .push(let make)? = action { return make() }
        return nil
    }
}

enum ToolboxCatalog {
    private static func item(
        _ id: String, _ title: String, _ systemImage: String, _ section: ToolboxItem.Section,
        _ action: ToolboxItem.Action? = nil
    ) -> ToolboxItem {
        ToolboxItem(id: id, title: title, systemImage: systemImage, section: section, action: action)
    }

    static let items: [ToolboxItem] = [
        item("schedule", "个人课表", "calendar", .info, .tab(.schedule)),
        item("classSchedule", "班级课表", "person.3", .info, .push { AnyView(CampusFeature.makeClassScheduleView { AnyView(JwScheduleExportView(classSchedule: true)) }) }),
        item("exportSchedule", "导出课表", "square.and.arrow.up", .info, .push { AnyView(JwScheduleExportView()) }),
        item("examInfo", "考试考场", "building.2", .info, .push { AnyView(ExamInfoView()) }),
        item("examScore", "考试成绩", "chart.bar.doc.horizontal", .info, .push { AnyView(ScoreWithPendingView()) }),
        item("attendance", "考勤信息", "person.badge.clock", .info, .push { AnyView(AttendanceView()) }),
        item("electiveStrategy", "校选课查漏", "checklist", .info, .push { AnyView(ElectiveStrategyView()) }),
        item("teacherInfo", "教师查询", "person.text.rectangle", .info, .push { AnyView(TeacherSearchView()) }),
        item("emptyClassroom", "空闲教室", "calendar.badge.clock", .info, .push { AnyView(CampusFeature.makeEmptyClassroomView()) }),
        item("campusNetwork", "校园网用量", "wifi", .info, .push { AnyView(AppComposition.makeCampusNetworkView()) }),
        item("phyExp", "物理实验课", "atom", .practice, .push { AnyView(CampusFeature.makePhyExpView()) }),
        item("engTraining", "金工实训", "wrench.and.screwdriver", .practice, .push { AnyView(CampusFeature.makeEngTrainingView()) }),
        item("timeShift", "调休信息", "calendar.badge.exclamationmark", .notice, .push { AnyView(TimeShiftView()) }),
        item("holiday", "节假日", "sun.max", .notice, .push { AnyView(HolidayView()) }),
        item("oaFiles", "学校文件", "doc.text", .notice, .push { AnyView(AccountFeature.makeOAFilesView()) }),
        item("evaluation", "期末学生评价", "text.badge.checkmark", .evaluation),
        item("campusMap", "地图导航", "map", .other, .push { AnyView(CampusFeature.makeMapNavigationView()) }),
        item("fullSchedule", "全校实时课表", "building.columns", .other, .push { AnyView(CampusFeature.makeFullScheduleView()) }),
        item("floorPlan", "教学楼平面图", "building.2.crop.circle", .other, .push { AnyView(CampusFeature.makeTeachBuildingMapView()) }),
    ]
}
