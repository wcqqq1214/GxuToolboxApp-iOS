import GxuDesign
import ScheduleKit
import SwiftUI

/// 新增 / 编辑自定义日程。用系统 Form；保存按钮在没填名字时不可用。
struct ActivityEditorSheet: View {
    @State var activity: CustomActivity
    let isNew: Bool
    let weekCount: Int
    let palette: CoursePalette
    let onSave: (CustomActivity) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（必填）", text: $activity.name)
                    TextField("备注（可选）", text: $activity.note, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("时间") {
                    Picker("星期", selection: $activity.weekday) {
                        ForEach(1...7, id: \.self) { Text(WeekdayName.full($0)).tag($0) }
                    }
                    Picker("开始", selection: beginBinding) {
                        ForEach(ClassPeriods.all, id: \.number) { Text("第 \($0.number) 节  \($0.startText)").tag($0.number) }
                    }
                    Picker("结束", selection: endBinding) {
                        ForEach(ClassPeriods.all.filter { $0.number >= activity.begin }, id: \.number) {
                            Text("第 \($0.number) 节  \($0.endText)").tag($0.number)
                        }
                    }
                    Picker("从", selection: weekFromBinding) {
                        ForEach(1...weekCount, id: \.self) { Text("第 \($0) 周").tag($0) }
                    }
                    Picker("到", selection: $activity.weekTo) {
                        ForEach(activity.weekFrom...max(weekCount, activity.weekFrom), id: \.self) { Text("第 \($0) 周").tag($0) }
                    }
                }

                Section("颜色") {
                    ColorSwatches(selected: $activity.colorHex, colors: palette.colors)
                }

                if let onDelete {
                    Section {
                        Button("删除日程", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "添加日程" : "编辑日程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(activity)
                        dismiss()
                    }
                    .disabled(!activity.isValid)
                }
            }
        }
        .presentationDetents([.large])
    }

    // 开始晚于结束时把结束顺延；起始周晚于结束周时把结束周顺延
    private var beginBinding: Binding<Int> {
        Binding(get: { activity.begin }, set: {
            activity.begin = $0
            activity.end = max(activity.end, $0)
        })
    }
    private var endBinding: Binding<Int> {
        Binding(get: { max(activity.end, activity.begin) }, set: { activity.end = $0 })
    }
    private var weekFromBinding: Binding<Int> {
        Binding(get: { activity.weekFrom }, set: {
            activity.weekFrom = $0
            activity.weekTo = max(activity.weekTo, $0)
        })
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

/// 日程管理：列表、点击编辑、左滑删除、右上角添加
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
                    GxuEmptyView("还没有自己的日程", systemImage: "calendar.badge.plus", message: "添加社团活动、自习等，会和课程一起显示在课表里", actionTitle: "添加日程", action: onAdd)
                } else {
                    List {
                        ForEach(activities) { activity in
                            Button { onEdit(activity) } label: {
                                HStack(spacing: GxuDesign.Spacing.m) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(CourseTint(hex: activity.colorHex).marker)
                                        .frame(width: 5, height: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(activity.name).foregroundStyle(.primary)
                                        Text("\(activity.weekText) · \(WeekdayName.full(activity.weekday)) 第\(activity.begin)-\(activity.end)节")
                                            .font(.footnote)
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                            }
                            .swipeActions { Button("删除", role: .destructive) { onDelete(activity) } }
                        }
                    }
                }
            }
            .navigationTitle("我的日程")
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
