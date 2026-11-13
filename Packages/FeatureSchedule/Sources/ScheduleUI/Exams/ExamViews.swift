import GxuDesign
import ScheduleKit
import SwiftUI
import UIKit

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

    @State private var copied = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let status = exam.status(now: context.date)
            NavigationStack {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exam.title).font(.headline).foregroundStyle(status == .ended ? Color.secondary : Color.primary)
                            Text(status.text(start: exam.start))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(statusColor(status))
                        }
                        .accessibilityElement(children: .combine)
                        LabeledContent("时间") { Text(timeText).multilineTextAlignment(.trailing) }
                        LabeledContent("考场") { Text(locationText).textSelection(.enabled) }
                        LabeledContent("座位", value: seatText)
                        if !exam.kind.isEmpty { LabeledContent("类别", value: exam.kind) }
                    }
                    Section {
                        Button(copied ? "已复制考试信息" : "复制考试信息", systemImage: copied ? "checkmark" : "doc.on.doc") {
                            UIPasteboard.general.string = copyText
                            copied = true
                        }
                        .sensoryFeedback(.success, trigger: copied) { _, new in new }
                    }
                }
                .navigationTitle("考试")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var locationText: String { exam.location.isEmpty ? "考场待定" : exam.location }
    private var seatText: String { exam.seat.isEmpty ? "暂未公布" : exam.seat }

    private var copyText: String {
        [
            "课程：\(exam.title)",
            exam.kind.isEmpty ? nil : "类别：\(exam.kind)",
            "时间：\(timeText.replacingOccurrences(of: "\n", with: " "))",
            "考场：\(locationText)",
            "座位：\(seatText)",
        ].compactMap { $0 }.joined(separator: "\n")
    }

    private func statusColor(_ status: GridExamStatus) -> Color {
        if status == .ended { return .secondary }
        return status.isUrgent ? .red : .accentColor
    }

    private var timeText: String {
        let day = exam.start.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
        let clock = Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "en_GB"))
        return "\(day)\n\(exam.start.formatted(clock))–\(exam.end.formatted(clock))"
    }
}
