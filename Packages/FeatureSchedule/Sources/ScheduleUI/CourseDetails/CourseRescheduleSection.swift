import GxuDesign
import ScheduleKit
import SwiftUI

struct CourseRescheduleSection: View {
    enum Phase {
        case loading
        case loaded([CourseReschedule])
        case failed
    }

    let phase: Phase
    let retry: () -> Void

    var body: some View {
        Section("调课通知") {
            switch phase {
            case .loading:
                ProgressView("正在加载调课记录…")
            case .loaded(let records):
                if records.isEmpty {
                    Text("暂无调课记录").foregroundStyle(.secondary)
                } else {
                    ForEach(records.indices, id: \.self) { index in
                        recordDetails(records[index])
                    }
                }
            case .failed:
                Text("调课记录加载失败").foregroundStyle(.secondary)
                Button("重试加载调课记录", action: retry)
            }
        }
    }

    private func recordDetails(_ record: CourseReschedule) -> some View {
        VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
            field("类型", record.type)
            field("原因", record.reason)
            field("类别", record.reasonCategory)
            arrangement("原安排", record.before)
            arrangement("现安排", record.after)
        }
    }

    private func arrangement(_ title: String, _ value: CourseReschedule.Arrangement) -> some View {
        VStack(alignment: .leading, spacing: GxuDesign.Spacing.xs) {
            Text(title).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            field("周次", value.weeks)
            field("星期", value.weekday)
            field("节次", value.sections)
            field("教师", value.teacher)
            field("教室", value.venueName)
        }
    }

    @ViewBuilder
    private func field(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(title) {
                Text(value).multilineTextAlignment(.trailing)
            }
        }
    }
}
