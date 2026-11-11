import GxuDesign
import ScheduleKit
import SwiftUI

struct CourseRescheduleSection: View {
    enum Phase {
        case loading
        case loaded([CourseReschedule])
        case failed
    }

    private struct Field: Identifiable {
        let title: String
        let value: String
        var id: String { title }
    }

    private struct Notice {
        let type: String?
        let current: [Field]
        let original: [Field]
        let details: [Field]
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let phase: Phase
    let retry: () -> Void

    var body: some View {
        Section("调课通知") {
            switch phase {
            case .loading:
                ProgressView("正在加载调课记录…")
            case .loaded(let records):
                let notices = records.compactMap(notice(for:))
                if notices.isEmpty {
                    Text("暂无调课记录").foregroundStyle(.secondary)
                } else {
                    ForEach(notices.indices, id: \.self) { index in
                        recordDetails(notices[index])
                    }
                }
            case .failed:
                Text("调课记录加载失败").foregroundStyle(.secondary)
                Button("重试加载调课记录", action: retry)
            }
        }
    }

    private func notice(for record: CourseReschedule) -> Notice? {
        let type = content(record.type)
        let current = fields(for: record.after)
        let original = fields(for: record.before)
        let reason = content(record.reason)
        let category = content(record.reasonCategory)
        let details = [
            fieldValue("调整原因", reason),
            fieldValue("原因类别", category == "其他" || category == reason ? nil : category),
        ].compactMap { $0 }
        guard type != nil || !current.isEmpty || !original.isEmpty || !details.isEmpty else { return nil }
        return Notice(type: type, current: current, original: original, details: details)
    }

    private func recordDetails(_ notice: Notice) -> some View {
        VStack(alignment: .leading, spacing: GxuDesign.Spacing.m) {
            if let type = notice.type {
                Text(type)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            if !notice.current.isEmpty {
                VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
                    Text("调整后安排")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityAddTraits(.isHeader)
                    fieldGrid(notice.current)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(GxuDesign.Spacing.m)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: GxuDesign.Radius.block))
            }
            if !notice.details.isEmpty {
                fieldGrid(notice.details)
            }
            if !notice.original.isEmpty {
                DisclosureGroup("查看原安排") {
                    fieldGrid(notice.original)
                        .padding(.top, GxuDesign.Spacing.s)
                }
            }
        }
        .padding(.vertical, GxuDesign.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fields(for arrangement: CourseReschedule.Arrangement) -> [Field] {
        [
            fieldValue("周次", arrangement.weeks),
            fieldValue("星期", arrangement.weekday),
            fieldValue("节次", arrangement.sections),
            fieldValue("教室", arrangement.venueName),
            fieldValue("教师", arrangement.teacher),
        ].compactMap { $0 }
    }

    private func fieldGrid(_ fields: [Field]) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: GxuDesign.Spacing.m, verticalSpacing: GxuDesign.Spacing.s) {
            ForEach(fields) { field in
                fieldRow(field)
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: Field) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: GxuDesign.Spacing.xs) {
                Text(field.title).font(.subheadline).foregroundStyle(.secondary)
                Text(field.value).font(.body)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
        } else {
            GridRow(alignment: .top) {
                Text(field.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Text(field.value)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func fieldValue(_ title: String, _ value: String?) -> Field? {
        content(value).map { Field(title: title, value: $0) }
    }

    private func content(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
