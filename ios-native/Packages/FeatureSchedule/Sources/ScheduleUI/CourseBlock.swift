import GxuDesign
import ScheduleKit
import SwiftUI

/// 周网格里的一个课程块。内容层：纯色圆角块，不用玻璃。
/// 冲突组只显示第一门，右上角角标显示门数。
struct CourseBlock: View {
    let group: ConflictGroup
    let colors: [String: UInt32]
    let rowHeight: CGFloat

    private var course: TheoryCourse { group.items[0].course }
    private var rows: Int { group.end - group.begin + 1 }
    private var tint: CourseTint { CourseTint(hex: colors[course.courseName] ?? 0xC7CEEA) }

    var body: some View {
        VStack(spacing: 2) {
            Text(course.courseName)
                .font(.caption2.weight(.semibold))
                .lineLimit(rows >= 2 ? 3 : 2)
            if !course.venueName.isEmpty {
                Text(LocationFormatter.blockText(venue: course.venueName, singleLine: rows < 2))
                    .lineLimit(rows >= 2 ? 2 : 1)
            }
            if rows >= 2, !course.teacher.isEmpty {
                Text(course.teacher).lineLimit(rows >= 3 ? 2 : 1)
            }
        }
        .font(.caption2)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.85)
        .foregroundStyle(tint.text)
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(tint.fill, in: RoundedRectangle(cornerRadius: GxuDesign.Radius.block, style: .continuous))
        .overlay(alignment: .topLeading) {
            if group.items.contains(where: \.isMakeup) {
                Text("补")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint.fill)
                    .frame(width: 14, height: 14)
                    .background(tint.text, in: Circle())
                    .offset(x: -3, y: -3)
            }
        }
        .overlay(alignment: .topTrailing) {
            if group.isConflict {
                Text("\(group.items.count)")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(tint.fill)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(tint.text, in: Capsule())
                    .offset(x: 3, y: -3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        let place = course.venueName.isEmpty ? "" : "，\(course.venueName)"
        let conflict = group.isConflict ? "，另有 \(group.items.count - 1) 门课冲突" : ""
        let makeup = group.items[0].isMakeup ? "，补班" : ""
        return "\(course.courseName)\(place)，\(WeekdayName.full(group.items[0].weekday)) 第\(group.begin)到\(group.end)节\(makeup)\(conflict)"
    }
}
