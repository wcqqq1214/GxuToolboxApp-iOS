import GxuDesign
import ScheduleKit
import SwiftUI

struct CourseRescheduleSection: View {
    let records: [CourseReschedule]

    var body: some View {
        let notices = records.map { (reason: content($0.reason), category: content($0.reasonCategory)) }
            .filter { $0.reason != nil || $0.category != nil }
        if !notices.isEmpty {
            Section("调课通知") {
                ForEach(notices.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
                        field("原因", notices[index].reason)
                        field("类别", notices[index].category)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func field(_ title: String, _ value: String?) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: GxuDesign.Spacing.xs) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Text(value).font(.body)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
        }
    }

    private func content(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
