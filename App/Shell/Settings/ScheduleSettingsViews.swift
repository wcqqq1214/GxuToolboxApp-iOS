import GxuDesign
import ScheduleKit
import SwiftUI

struct ScheduleAppearanceSettingsView: View {
    @Environment(SchedulePreferencesStore.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        List {
            Section("课程配色") {
                ForEach(CoursePalette.allCases, id: \.self) { palette in
                    Button { preferences.value.palette = palette } label: {
                        HStack(spacing: GxuDesign.Spacing.m) {
                            Text(palette.displayName).foregroundStyle(.primary)
                            Spacer()
                            HStack(spacing: -6) {
                                ForEach(Array(palette.colors.prefix(6)), id: \.self) { hex in
                                    Circle().fill(CourseTint(hex: hex).marker).frame(width: 20, height: 20)
                                        .overlay { Circle().strokeBorder(Color(.systemBackground), lineWidth: 1.5) }
                                }
                            }
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .opacity(preferences.value.palette == palette ? 1 : 0)
                        }
                    }
                    .accessibilityAddTraits(preferences.value.palette == palette ? .isSelected : [])
                }
            }
            Section {
                Toggle("课程块显示地点", isOn: $preferences.value.showVenueInBlock)
                Toggle("课程块显示教师", isOn: $preferences.value.showTeacherInBlock)
            } header: {
                Text("课程块内容")
            } footer: {
                Text("课程名始终显示。关闭后课程块更简洁，点开详情仍能看到全部信息。")
            }
        }
        .navigationTitle("课表外观")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailFieldsSettingsView: View {
    enum Kind { case course, exam }
    let kind: Kind
    @Environment(SchedulePreferencesStore.self) private var preferences

    private var title: String { kind == .course ? "课程详情显示" : "考试详情显示" }
    private var defaults: [DetailFieldSetting] {
        kind == .course ? SchedulePreferences.courseFieldDefaults : SchedulePreferences.examFieldDefaults
    }
    private var fields: Binding<[DetailFieldSetting]> {
        Binding(
            get: { kind == .course ? preferences.value.courseDetail : preferences.value.examDetail },
            set: { if kind == .course { preferences.value.courseDetail = $0 } else { preferences.value.examDetail = $0 } }
        )
    }

    var body: some View {
        List {
            Section {
                ForEach(fields) { $field in
                    HStack(spacing: GxuDesign.Spacing.m) {
                        TextField("名称", text: $field.label)
                            .foregroundStyle(field.isShown ? .primary : .secondary)
                        Toggle("显示", isOn: $field.isShown).labelsHidden()
                    }
                }
                .onMove { fields.wrappedValue.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("关闭的项目不会显示；点“编辑”可以拖动调整顺序；点名称可以改成自己习惯的叫法。内容为空的项目自动隐藏。")
            }
            Section {
                Button("恢复默认", role: .destructive) { fields.wrappedValue = defaults }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }
}
