import GxuDesign
import ScheduleKit
import SwiftUI

/// 课程详情。系统 sheet（自动是玻璃），带 detents；冲突组时依次列出每一门课。
struct CourseDetailSheet: View {
    let group: ConflictGroup
    let colors: [String: UInt32]
    let selected: CourseOccurrence
    var exams: [GridExam] = []
    var attendance: AttendanceIndex?
    let onChoose: (CourseOccurrence) -> Void
    let onEditActivity: (String?) -> Void
    @Environment(SchedulePreferencesStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    /// 点选后立刻反映在 sheet 里（外面的 `selected` 要等持久化后才变）
    @State private var chosenID: String?

    private var currentID: String { chosenID ?? selected.id }

    var body: some View {
        NavigationStack {
            List {
                if group.isConflict {
                    Section {
                        Label("这个时段有 \(group.items.count) 门课冲突", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("课表、首页和小组件里只显示选中的那一门。")
                    }
                }
                ForEach(group.items) { item in
                    CourseSection(
                        item: item, tint: CourseTint(hex: colors[item.course.courseName] ?? 0xC7CEEA),
                        choice: group.isConflict ? (isSelected: item.id == currentID, choose: {
                            chosenID = item.id
                            onChoose(item)
                        }) : nil,
                        fields: preferences.value.courseDetail.filter(\.isShown),
                        exams: item.course.isCustom ? [] : RelatedExams.matching(courseName: item.course.courseName, in: exams),
                        attendance: attendance?.status(for: item),
                        onEditActivity: onEditActivity
                    )
                }
            }
            .navigationTitle(group.isConflict ? "冲突课程" : group.items[0].course.courseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .presentationDetents(Self.detents)
        .presentationDragIndicator(.visible)
    }

    private static var detents: Set<PresentationDetent> {
        #if DEBUG
        if CommandLine.arguments.contains("-GxuSheetLarge") { return [.large] }   // 截图自查：直接看到整张详情
        #endif
        return [.medium, .large]
    }
}

private struct CourseSection: View {
    let item: CourseOccurrence
    let tint: CourseTint
    var choice: (isSelected: Bool, choose: () -> Void)?
    let fields: [DetailFieldSetting]
    var exams: [GridExam] = []
    var attendance: AttendanceStatus?
    let onEditActivity: (String?) -> Void
    @Environment(\.scheduleMapURL) private var mapURL
    @Environment(\.scheduleTeacherSupport) private var teacherSupport
    @Environment(\.openURL) private var openURL
    private var course: TheoryCourse { item.course }

    var body: some View {
        Section {
            if sectionHasHeader { header }
            if let from = item.shiftedFrom {
                Label("补班：按 \(from.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))) 的课表上课", systemImage: "arrow.triangle.swap")
                    .foregroundStyle(.orange)
            }
            if course.isCustom {
                // 实验课只有这几项有意义；备注放在“考核”字段里（见 `CustomActivity.course`）
                row("时间", "\(WeekdayName.full(item.weekday)) 第\(course.begin)-\(course.end)节  \(timeText)")
                row("周次", WeekFormatter.describe(course.weeks))
                row("地点", course.venueName)
                row("教师", course.teacher)
                row("备注", course.examMethod)
                Button("编辑实验课", systemImage: "pencil") { onEditActivity(course.customID) }
            } else {
                if let attendance { row("考勤", attendance.label) }
                if let teacherSupport, !course.teacher.isEmpty {
                    TeacherCard(name: course.teacher, support: teacherSupport)
                }
                ForEach(fields) { field in
                    // 教师卡片已经写了教师，同一张卡片里同一信息只出现一次
                    if !(field.id == "teacher" && teacherSupport != nil && !course.teacher.isEmpty) {
                        row(field.label, value(of: field.id))
                    }
                    if field.id == "venue", let url = navigationURL {
                        Button("导航到这里", systemImage: "location.fill") { openURL(url) }
                    }
                }
            }
            if let choice {
                if choice.isSelected {
                    Label("正在课表中显示", systemImage: "checkmark.circle.fill").foregroundStyle(.tint)
                } else {
                    Button("在课表中显示这门课", systemImage: "eye", action: choice.choose)
                }
            }
        }
        if !exams.isEmpty {
            Section("相关考试") {
                ForEach(exams) { exam in RelatedExamRow(exam: exam) }
            }
        }
    }

    private var navigationURL: URL? {
        CourseNavigation.target(building: course.building, venue: course.venueName).flatMap { mapURL?($0) }
    }

    private func value(of field: String) -> String {
        switch field {
        case "time": "\(WeekdayName.full(item.weekday)) 第\(course.begin)-\(course.end)节  \(timeText)"
        case "weeks": WeekFormatter.describe(course.weeks)
        case "venue": LocationFormatter.display(building: course.building, venue: course.venueName)
        case "teacher": course.teacher
        case "credits": course.credits
        case "category": course.courseCategory
        case "examMethod": course.examMethod
        case "enrollment": course.enrollmentCount > 0 ? "\(course.enrollmentCount)" : ""
        case "qqGroup": course.qqGroup
        default: ""
        }
    }

    private var sectionHasHeader: Bool { true }

    private var header: some View {
        HStack(spacing: GxuDesign.Spacing.m) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(tint.marker)
                .frame(width: 6, height: 28)
            Text(course.courseName).font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var timeText: String {
        guard let first = ClassPeriods.period(course.begin), let last = ClassPeriods.period(course.end) else { return "" }
        return "\(first.startText)–\(last.endText)"
    }

    /// 空值不显示
    @ViewBuilder
    private func row(_ title: String, _ value: String) -> some View {
        if !value.isEmpty {
            LabeledContent(title) {
                Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
            }
        }
    }
}


private struct RelatedExamRow: View {
    let exam: GridExam

    var body: some View {
        let badge = RelatedExams.badge(for: exam, now: .now)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exam.start.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "zh_CN"))))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(badge).font(.caption.weight(.medium))
                    .foregroundStyle(badge == "已结束" ? Color.secondary : Color.orange)
            }
            Text("\(exam.start.formatted(.dateTime.hour().minute()))–\(exam.end.formatted(.dateTime.hour().minute()))")
                .font(.footnote).foregroundStyle(.secondary)
            let detail = [exam.location, exam.seat].filter { !$0.isEmpty }.joined(separator: " · ")
            if !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .combine)
    }
}


/// 任课教师卡片：头像、姓名、单位、查看详情（进入教师查询）
private struct TeacherCard: View {
    let name: String
    let support: ScheduleTeacherSupport
    @State private var info: ScheduleTeacherSupport.Info?

    var body: some View {
        NavigationLink {
            support.destination(name)
        } label: {
            HStack(spacing: GxuDesign.Spacing.m) {
                ZStack {
                    Color.accentColor.opacity(0.15)
                    Text(String(name.prefix(1))).font(.title3.weight(.semibold)).foregroundStyle(Color.accentColor)
                    if let url = info?.avatarURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                        }
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.headline)
                    if let unit = info?.unit, !unit.isEmpty { Text(unit).font(.footnote).foregroundStyle(.secondary) }
                    Text("查看详情").font(.footnote).foregroundStyle(.tint)
                }
            }
        }
        .accessibilityHint("查看教师详情")
        .task(id: name) { info = await support.lookup(name) }
    }
}
