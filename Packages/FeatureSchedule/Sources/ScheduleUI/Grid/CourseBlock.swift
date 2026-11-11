import GxuDesign
import ScheduleKit
import SwiftUI

struct CourseBlock: View {
    let group: ConflictGroup
    let selected: CourseOccurrence
    let colors: [String: UInt32]
    let rowHeight: CGFloat
    var showVenue = true
    var showTeacher = true
    var attendance: AttendanceStatus?

    private var course: TheoryCourse { selected.course }
    private var rows: Int { PeriodRows.rows(begin: group.begin, end: group.end).count }
    private var tint: CourseTint { CourseTint(hex: colors[course.courseName] ?? 0xC7CEEA) }

    var body: some View {
        VStack(spacing: 2) {
            Text(course.courseName)
                .font(.caption.weight(.semibold))
                .lineLimit(rows >= 2 ? 3 : 2)
            if showVenue, !course.locationText.isEmpty {
                Text(LocationFormatter.blockText(venue: course.locationText, singleLine: rows < 2))
                    .lineLimit(rows >= 2 ? 2 : 1)
            }
            if showTeacher, rows >= 2, !course.teacher.isEmpty {
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
            HStack(spacing: 2) {
                if selected.isMakeup { scheduleBadge("补") }
                if course.isRescheduled { scheduleBadge("调") }
            }
            .offset(x: -3, y: -3)
        }
        .overlay(alignment: .bottomTrailing) {
            if let attendance { AttendanceBadge(status: attendance, tint: tint) }
        }
        .overlay(alignment: .topTrailing) {
            if group.isConflict {
                Text("\(group.items.count)")
                    .font(.caption2.weight(.bold).monospacedDigit())
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

    private func scheduleBadge(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint.fill)
            .fixedSize()
            .frame(minWidth: 14, minHeight: 14)
            .background(tint.text, in: Circle())
    }

    private var accessibilityText: String {
        let place = course.locationText.isEmpty ? "" : "，\(course.locationText)"
        let conflict = group.isConflict ? "，另有 \(group.items.count - 1) 门课冲突" : ""
        let makeup = selected.isMakeup ? "，补班" : ""
        let rescheduled = course.isRescheduled ? "，已调课" : ""
        let attend = attendance.map { "，\($0.label)" } ?? ""
        return "\(course.courseName)\(place)，\(WeekdayName.full(selected.weekday)) 第\(group.begin)到\(group.end)节\(makeup)\(rescheduled)\(attend)\(conflict)"
    }
}


struct AttendanceBadge: View {
    let status: AttendanceStatus
    let tint: CourseTint

    var body: some View {
        Image(systemName: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint.text.opacity(status == .notStarted || status == .noNeed ? 0.6 : 1))
            .padding(2)
    }

    private var symbol: String {
        switch status {
        case .normal: "checkmark.circle.fill"
        case .late: "clock.fill"
        case .absent: "xmark.circle.fill"
        case .notStarted: "circle"
        case .noNeed: "minus.circle"
        }
    }
}
