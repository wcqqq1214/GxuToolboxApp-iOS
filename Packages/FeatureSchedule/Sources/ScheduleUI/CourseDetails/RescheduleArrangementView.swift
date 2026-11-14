import GxuDesign
import SwiftUI

struct RescheduleArrangementView: View {
    enum Stage: String {
        case before = "调整前"
        case after = "调整后"
    }

    let stage: Stage
    let summary: RescheduleArrangementSummary

    var body: some View {
        VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
            Group {
                if stage == .after {
                    Label(stage.rawValue, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else {
                    Text(stage.rawValue).foregroundStyle(.secondary)
                }
            }
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
            field("周次", summary.weeks)
            field("星期", summary.weekday)
            field("节次", summary.sections)
            field("地点", summary.venue)
            field("教师", summary.teacher)
        }
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(stage.rawValue)
    }

    private func field(_ title: String, _ value: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(stage == .after ? .primary : .secondary)
        } label: {
            Text(title)
                .foregroundStyle(stage == .after ? .primary : .secondary)
        }
    }
}
