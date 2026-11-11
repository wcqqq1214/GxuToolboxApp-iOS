import GxuDesign
import ScheduleKit
import SwiftUI

struct ExamBlockView: View {
    let block: ExamBlock
    let rows: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("考试")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 5)
                .background(Color.red, in: Capsule())
            Text(block.exam.title)
                .font(.caption.weight(.semibold))
                .lineLimit(rows >= 2 ? 3 : 2)
            if !block.exam.location.isEmpty {
                Text(block.exam.location).font(.caption2).lineLimit(rows >= 2 ? 2 : 1)
            }
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.85)
        .foregroundStyle(Color.red.mix(with: .primary, by: 0.45))
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: GxuDesign.Radius.block, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: GxuDesign.Radius.block, style: .continuous).strokeBorder(Color.red.opacity(0.5), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("考试，\(block.exam.title)，\(block.exam.location)，\(WeekdayName.full(block.weekday)) 第\(block.begin)到\(block.end)节")
        .accessibilityAddTraits(.isButton)
    }
}

struct ExamDetailSheet: View {
    let exam: GridExam
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(exam.title).font(.headline)
                    LabeledContent("时间") { Text(timeText).multilineTextAlignment(.trailing) }
                    if !exam.location.isEmpty { LabeledContent("考场", value: exam.location) }
                    if !exam.seat.isEmpty { LabeledContent("座位", value: exam.seat) }
                }
            }
            .navigationTitle("考试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }

    private var timeText: String {
        let day = exam.start.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
        let clock = Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "en_GB"))
        return "\(day)\n\(exam.start.formatted(clock))–\(exam.end.formatted(clock))"
    }
}
