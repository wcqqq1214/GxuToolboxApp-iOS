import GxuDesign
import ScheduleKit
import SwiftUI

/// 课程详情。系统 sheet（自动是玻璃），带 detents；冲突组时依次列出每一门课。
struct CourseDetailSheet: View {
    let group: ConflictGroup
    let colors: [String: UInt32]
    let selected: CourseOccurrence
    let onChoose: (CourseOccurrence) -> Void
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
                        }) : nil
                    )
                }
            }
            .navigationTitle(group.isConflict ? "冲突课程" : group.items[0].course.courseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct CourseSection: View {
    let item: CourseOccurrence
    let tint: CourseTint
    var choice: (isSelected: Bool, choose: () -> Void)?
    private var course: TheoryCourse { item.course }

    var body: some View {
        Section {
            if sectionHasHeader { header }
            if let from = item.shiftedFrom {
                Label("补班：按 \(from.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))) 的课表上课", systemImage: "arrow.triangle.swap")
                    .foregroundStyle(.orange)
            }
            row("时间", "\(WeekdayName.full(item.weekday)) 第\(course.begin)-\(course.end)节  \(timeText)")
            row("周次", WeekFormatter.describe(course.weeks))
            row("地点", LocationFormatter.display(building: course.building, venue: course.venueName))
            row("教师", course.teacher)
            row("学分", course.credits)
            row("类别", course.courseCategory)
            row("考核", course.examMethod)
            row("选课人数", course.enrollmentCount > 0 ? "\(course.enrollmentCount)" : "")
            row("QQ 群", course.qqGroup)
            if let choice {
                if choice.isSelected {
                    Label("正在课表中显示", systemImage: "checkmark.circle.fill").foregroundStyle(.tint)
                } else {
                    Button("在课表中显示这门课", systemImage: "eye", action: choice.choose)
                }
            }
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
    private func row(_ title: LocalizedStringKey, _ value: String) -> some View {
        if !value.isEmpty {
            LabeledContent(title) {
                Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
            }
        }
    }
}
