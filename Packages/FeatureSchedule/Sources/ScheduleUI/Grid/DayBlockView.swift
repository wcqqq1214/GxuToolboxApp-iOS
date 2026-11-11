import GxuDesign
import ScheduleKit
import SwiftUI

struct DayRun: Identifiable {
    let blocks: [DayBlock]
    var id: String { "\(blocks[0].id)+\(blocks.count)" }
    var firstWeekday: Int { blocks[0].weekday }
    var days: Int { blocks.count }
    var title: String { blocks[0].title }
    var kind: DayBlock.Kind { blocks[0].kind }

    static func runs(_ blocks: [DayBlock]) -> [DayRun] {
        var result: [[DayBlock]] = []
        for block in blocks.sorted(by: { $0.weekday < $1.weekday }) {
            if let last = result.last?.last, last.title == block.title, last.kind == block.kind, last.weekday + 1 == block.weekday {
                result[result.count - 1].append(block)
            } else {
                result.append([block])
            }
        }
        return result.map(DayRun.init)
    }
}

struct DayBlockView: View {
    let run: DayRun

    private var systemImage: String {
        switch run.kind {
        case .rest: "moon.zzz"
        case .holiday(.school): "figure.run"
        case .holiday: "sun.max"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).font(.footnote)
            Text(run.title)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.green.mix(with: .primary, by: 0.35))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: GxuDesign.Radius.block, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(run.title)，\(run.kind == .rest ? "调休休息" : "放假")\(run.days > 1 ? "，共 \(run.days) 天" : "")")
    }
}

struct PracticeSection: View {
    let courses: [PracticeCourse]

    var body: some View {
        if !courses.isEmpty {
            VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
                Text("实践课").gxuSectionHeader()
                VStack(spacing: 0) {
                    ForEach(Array(courses.enumerated()), id: \.offset) { index, course in
                        if index > 0 { Divider().padding(.leading, GxuDesign.Layout.cardInset) }
                        HStack(spacing: GxuDesign.Spacing.m) {
                            Image(systemName: "wrench.and.screwdriver").foregroundStyle(.tint).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.title).font(.subheadline.weight(.medium))
                                let detail = [course.time, course.teacher].filter { !$0.isEmpty }.joined(separator: " · ")
                                if !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(.secondary) }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, GxuDesign.Spacing.m)
                        .padding(.horizontal, GxuDesign.Layout.cardInset)
                        .accessibilityElement(children: .combine)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: GxuDesign.Radius.card, style: .continuous))
            }
            .padding(.horizontal, GxuDesign.Layout.pageMargin)
            .padding(.top, GxuDesign.Spacing.l)
        }
    }
}
