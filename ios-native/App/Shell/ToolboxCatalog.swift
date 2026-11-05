import FeatureCourse
import FeatureExam
import SwiftUI

struct ToolboxItem: Identifiable {
    enum Section: String, CaseIterable, Identifiable {
        case academic = "学业"
        case campus = "校园"
        case service = "服务"
        var id: String { rawValue }
    }

    let id: String
    let title: String
    let systemImage: String
    let section: Section
    /// nil = 即将上线。上线时把对应一行的最后一个参数换成 `{ XxxFeature.makeRootView() }`
    let destination: (@MainActor () -> AnyView)?

    var isAvailable: Bool { destination != nil }
}

/// 工具箱里的全部功能。**每个功能一行**：各 Agent 只改自己功能的那一行（把 nil 换成入口），不要动别人的行。
enum ToolboxCatalog {
    private static func item(
        _ id: String, _ title: String, _ systemImage: String, _ section: ToolboxItem.Section,
        _ destination: (@MainActor () -> AnyView)? = nil
    ) -> ToolboxItem {
        ToolboxItem(id: id, title: title, systemImage: systemImage, section: section, destination: destination)
    }

    static let items: [ToolboxItem] = [
        // 学业
        item("examInfo", "考试信息", "calendar.badge.clock", .academic, { AnyView(ExamInfoView()) }),
        item("examScore", "成绩查询", "checkmark.seal", .academic, { AnyView(ScoreView()) }),
        item("gpa", "GPA 计算", "function", .academic, { AnyView(GpaView()) }),
        item("selectedCourse", "已选课程", "books.vertical", .academic),
        item("electiveStrategy", "选课策略", "list.bullet.clipboard", .academic),
        item("reschedulingNews", "调休补班", "calendar.badge.clock", .academic, { AnyView(TimeShiftView()) }),
        item("evaluation", "教学评价", "text.bubble", .academic),
        // 校园
        item("classSchedule", "班级课表", "person.3", .campus),
        item("fullSchedule", "全校课表", "building.columns", .campus),
        item("campusMap", "校园地图", "map", .campus),
        item("practice", "实践课", "flask", .campus),
        item("holiday", "节假日", "sun.max", .campus, { AnyView(HolidayView()) }),
        item("teacherInfo", "教师查询", "person.text.rectangle", .campus),
        // 服务
        item("attendance", "考勤查询", "person.badge.clock", .service),
        item("eduRecharge", "校园网充值", "wifi", .service),
        item("oaFiles", "OA 文件", "doc.text", .service),
    ]
}
