import GxuDesign
import GxuFoundation
import ScheduleKit
import SwiftUI

/// 课程详情。系统 sheet（自动是玻璃），带 detents；冲突组时依次列出每一门课。
struct CourseDetailSheet: View {
    let group: ConflictGroup
    let colors: [String: UInt32]
    let selected: CourseOccurrence
    var exams: [GridExam] = []
    /// 课表正在查看的学期，相关考试只显示这个学期的
    var term: AcademicTerm?
    var attendance: AttendanceIndex?
    let onChoose: (CourseOccurrence) -> Void
    let onEditActivity: (String?) -> Void
    @Environment(SchedulePreferencesStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    /// 点选后立刻反映在 sheet 里（外面的 `selected` 要等持久化后才变）
    @State private var chosenID: String?
    @Environment(\.scheduleMapPlan) private var mapPlan
    @Environment(\.openURL) private var openURL
    @State private var pendingMap: PendingMap?
    @State private var toast: String?

    private struct PendingMap: Identifiable {
        let keyword: String
        let apps: [MapApp]
        var id: String { keyword }
    }

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
                        exams: item.course.isCustom ? [] : RelatedExams.matching(courseName: item.course.courseName, in: exams, term: term),
                        attendance: attendance?.status(for: item),
                        onEditActivity: onEditActivity,
                        onNavigate: navigateAction
                    )
                }
            }
            .navigationTitle(group.isConflict ? "冲突课程" : group.items[0].course.courseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .gxuToast($toast)
            #if DEBUG
            .task { debugMapAction() }
            #endif
            .confirmationDialog("请选择打开方式", isPresented: mapDialogShown, titleVisibility: .visible, presenting: pendingMap) { pending in
                mapChoices(pending)
            }
        }
        .presentationDetents(Self.detents)
        .presentationDragIndicator(.visible)
    }

    #if DEBUG
    /// 截图自查：`-GxuMapAction unparsed|choose` 直接走一遍“解析不到提示 / 选地图应用”
    private func debugMapAction() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-GxuMapAction"), i + 1 < args.count else { return }
        let course = group.items[0].course
        switch args[i + 1] {
        case "unparsed": navigate(CourseNavigation.Target(text: "未知楼 | 9Z-999", mapKeyword: nil))
        default: if let target = CourseNavigation.target(building: course.building, venue: course.venueName) { navigate(target) }
        }
    }
    #endif

    private var navigateAction: ((CourseNavigation.Target) -> Void)? {
        mapPlan == nil ? nil : { target in navigate(target) }
    }

    private var mapDialogShown: Binding<Bool> {
        Binding(get: { pendingMap != nil }, set: { if !$0 { pendingMap = nil } })
    }

    @ViewBuilder
    private func mapChoices(_ pending: PendingMap) -> some View {
        ForEach(pending.apps, id: \.self) { app in
            Button(app.label) { open(app, keyword: pending.keyword) }
        }
    }

    /// RN `useMapNavigation.openMap`：解析不到 / 没有地图应用 → 提示；一个 → 直接打开；多个 → 让用户选
    private func navigate(_ target: CourseNavigation.Target) {
        guard let mapPlan else { return }
        switch mapPlan(target) {
        case .unparsed: toast = MapOpenPlan.unparsedMessage
        case .noApp: toast = MapOpenPlan.noAppMessage
        case .open(let keyword, let apps):
            if apps.count == 1, let app = apps.first { open(app, keyword: keyword) } else { pendingMap = PendingMap(keyword: keyword, apps: apps) }
        }
    }

    private func open(_ app: MapApp, keyword: String) {
        guard let url = app.url(keyword: keyword) else { toast = MapOpenPlan.openFailedMessage(app); return }
        openURL(url) { accepted in if !accepted { toast = MapOpenPlan.openFailedMessage(app) } }
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
    /// 地点行的“导航到这里”；没有注入地图能力时为 nil（不显示按钮）
    var onNavigate: ((CourseNavigation.Target) -> Void)?
    @Environment(\.scheduleTeacherSupport) private var teacherSupport
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
                row("地点", course.locationText)
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
                    if field.id == "venue", let onNavigate, let target = navigationTarget {
                        Button("导航到这里", systemImage: "location.fill") { onNavigate(target) }
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

    private var navigationTarget: CourseNavigation.Target? {
        CourseNavigation.target(building: course.building, venue: course.venueName)
    }

    private func value(of field: String) -> String {
        switch field {
        case "time": "\(WeekdayName.full(item.weekday)) 第\(course.begin)-\(course.end)节  \(timeText)"
        case "weeks": WeekFormatter.describe(course.weeks)
        case "venue": course.locationText
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
