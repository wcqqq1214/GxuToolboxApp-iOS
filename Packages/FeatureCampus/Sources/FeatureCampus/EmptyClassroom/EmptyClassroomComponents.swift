import ScheduleKit
import SwiftUI

struct PeriodStrip: View {
    var freeRuns: [FreeRun]
    var highlight: ClosedRange<Int>?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...EmptyClassroomConstants.periods, id: \.self) { period in
                let free = freeRuns.contains { (($0.begin)...($0.end)).contains(period) }
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(free ? Color.green.opacity(0.75) : Color(.tertiarySystemFill))
                    .frame(height: 8)
                    .overlay {
                        if let highlight, highlight != 1...EmptyClassroomConstants.periods, highlight.contains(period) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

func runText(_ runs: [FreeRun]) -> String {
    runs.map { $0.begin == $0.end ? "第\($0.begin)节" : "第\($0.begin)-\($0.end)节" }.joined(separator: "、")
}

@MainActor @ViewBuilder
func termPicker(_ model: EmptyClassroomModel) -> some View {
    if model.context.terms.count > 1 {
        Picker("学期", selection: Binding(get: { model.term ?? model.context.terms[0] }, set: { term in Task { await model.select(term: term) } })) {
            ForEach(model.context.terms, id: \.self) { Text($0.displayName).tag($0) }
        }
    }
}
