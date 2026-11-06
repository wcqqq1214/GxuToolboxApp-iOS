import GxuDesign
import ScheduleKit
import SwiftUI

/// 新增 / 编辑实验课（RN `CustomEventsSheet` 的表单）：名称、教学周（文本，如 1-8,10,12）、星期、开始 / 结束节次、地点、教师、备注。
/// 草稿只在点“保存”时校验并提交；校验信息写在表单里。
struct ActivityEditorSheet: View {
    @State var activity: CustomActivity
    let isNew: Bool
    let weekCount: Int
    let termTitle: String
    let palette: CoursePalette
    let onSave: (CustomActivity) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var weeksText: String
    @State private var message: String?
    @State private var confirmDelete = false

    init(
        activity: CustomActivity, isNew: Bool, weekCount: Int, termTitle: String, palette: CoursePalette,
        onSave: @escaping (CustomActivity) -> Void, onDelete: (() -> Void)?
    ) {
        _activity = State(initialValue: activity)
        _weeksText = State(initialValue: activity.weeksInputText)
        self.isNew = isNew
        self.weekCount = weekCount
        self.termTitle = termTitle
        self.palette = palette
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("实验课名称（必填）", text: $activity.name)
                } footer: {
                    Text(termTitle)
                }

                Section {
                    LabeledContent("教学周") {
                        TextField("教学周", text: $weeksText, prompt: Text("例如 1-8,10,12"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                    }
                    Picker("星期", selection: $activity.weekday) {
                        ForEach(1...7, id: \.self) { Text(WeekdayName.full($0)).tag($0) }
                    }
                    Picker("开始节次", selection: beginBinding) {
                        ForEach(ClassPeriods.all, id: \.number) { Text("第 \($0.number) 节  \($0.startText)").tag($0.number) }
                    }
                    Picker("结束节次", selection: endBinding) {
                        ForEach(ClassPeriods.all.filter { $0.number >= activity.begin }, id: \.number) {
                            Text("第 \($0.number) 节  \($0.endText)").tag($0.number)
                        }
                    }
                } header: {
                    Text("时间")
                } footer: {
                    if !isNew { Text("修改会应用到此实验课的所有教学周。") }
                }

                Section {
                    TextField("地点（选填）", text: $activity.location)
                    TextField("教师（选填）", text: $activity.teacher)
                    TextField("备注（选填）", text: $activity.note, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("颜色") {
                    ColorSwatches(selected: $activity.colorHex, colors: palette.colors)
                }

                if let message {
                    Section { Text(message).foregroundStyle(.red) }
                }

                if onDelete != nil {
                    Section {
                        Button("删除实验课", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? "添加实验课" : "编辑实验课")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: submit) }
            }
            .confirmationDialog("删除实验课", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("确定删除“\(activity.name)”及其所有重复安排？")
            }
        }
        .presentationDetents([.large])
    }

    private func submit() {
        message = nil
        do {
            activity.weeks = try TeachingWeeks.parse(weeksText, weekCount: weekCount)
        } catch {
            message = error.localizedDescription
            return
        }
        if let problem = activity.validationMessage {
            message = problem
            return
        }
        onSave(activity)
        dismiss()
    }

    // 开始晚于结束时把结束顺延
    private var beginBinding: Binding<Int> {
        Binding(get: { activity.begin }, set: {
            activity.begin = $0
            activity.end = max(activity.end, $0)
        })
    }
    private var endBinding: Binding<Int> {
        Binding(get: { max(activity.end, activity.begin) }, set: { activity.end = $0 })
    }
}

private struct ColorSwatches: View {
    @Binding var selected: UInt32
    let colors: [UInt32]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: GxuDesign.Spacing.m)], spacing: GxuDesign.Spacing.m) {
            ForEach(colors, id: \.self) { hex in
                let tint = CourseTint(hex: hex)
                Button { selected = hex } label: {
                    Circle()
                        .fill(tint.marker)
                        .frame(width: 34, height: 34)
                        .overlay {
                            if selected == hex {
                                Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("颜色 \(hex)")
                .accessibilityAddTraits(selected == hex ? .isSelected : [])
            }
        }
        .padding(.vertical, GxuDesign.Spacing.xs)
    }
}

/// 我的实验课：列表、点击编辑、左滑删除、右上角添加
struct ActivityListSheet: View {
    let activities: [CustomActivity]
    let onAdd: () -> Void
    let onEdit: (CustomActivity) -> Void
    let onDelete: (CustomActivity) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    GxuEmptyView("还没有实验课", systemImage: "flask", message: "添加实验课的教学周、星期和节次，会和课程一起显示在课表里", actionTitle: "添加实验课", action: onAdd)
                } else {
                    List {
                        ForEach(activities) { activity in
                            Button { onEdit(activity) } label: {
                                HStack(spacing: GxuDesign.Spacing.m) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(CourseTint(hex: activity.colorHex).marker)
                                        .frame(width: 5, height: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(activity.name).foregroundStyle(Color.primary)
                                        Text("\(activity.weekText) · \(WeekdayName.full(activity.weekday)) 第\(activity.begin)-\(activity.end)节")
                                            .font(.footnote)
                                            .foregroundStyle(Color.secondary)
                                        let extra = [activity.location, activity.teacher, activity.note].filter { !$0.isEmpty }.joined(separator: " · ")
                                        if !extra.isEmpty { Text(extra).font(.footnote).foregroundStyle(Color.secondary).lineLimit(1) }
                                    }
                                }
                            }
                            .swipeActions { Button("删除", role: .destructive) { onDelete(activity) } }
                        }
                    }
                }
            }
            .navigationTitle("我的实验课")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("添加", systemImage: "plus", action: onAdd) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
