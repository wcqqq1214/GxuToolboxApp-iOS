import GxuDesign
import ScheduleKit
import SwiftUI

struct CourseRescheduleSection: View {
    let records: [CourseReschedule]

    var body: some View {
        ForEach(records.indices, id: \.self) { index in
            let record = records[index]
            Section {
                RescheduleArrangementView(stage: .before, summary: RescheduleArrangementSummary(record.before))
                RescheduleArrangementView(stage: .after, summary: RescheduleArrangementSummary(record.after))
                if let type = RescheduleArrangementSummary.content(record.type) {
                    field("类型", type)
                }
                if let reason = RescheduleArrangementSummary.content(record.reason) {
                    field("原因", reason)
                }
                if let category = RescheduleArrangementSummary.content(record.reasonCategory) {
                    field("类别", category)
                }
            } header: {
                Text(records.count > 1 ? "调课通知 \(index + 1)" : "调课通知")
            }
        }
    }

    private func field(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: GxuDesign.Spacing.xs) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.body).textSelection(.enabled)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}
