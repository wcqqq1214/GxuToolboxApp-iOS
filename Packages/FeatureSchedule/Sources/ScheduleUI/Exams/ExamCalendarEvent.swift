import EventKit
import ScheduleKit

struct ExamCalendarEvent: Identifiable {
    let exam: GridExam
    var id: String { exam.id }

    init?(exam: GridExam) {
        guard exam.end > exam.start else { return nil }
        self.exam = exam
    }

    @MainActor
    func makeEvent(in store: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: store)
        let title = exam.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.title = title.isEmpty ? "考试" : "\(title) · 考试"
        event.startDate = exam.start
        event.endDate = exam.end
        event.isAllDay = false
        let location = exam.location.trimmingCharacters(in: .whitespacesAndNewlines)
        event.location = location.isEmpty ? nil : location
        event.notes = [
            exam.kind.isEmpty ? nil : "类别：\(exam.kind)",
            exam.seat.isEmpty ? nil : "座位：\(exam.seat)",
            "来自西大工具箱。考试安排变化后，请手动更新日历。",
        ].compactMap { $0 }.joined(separator: "\n")
        event.addAlarm(EKAlarm(relativeOffset: -30 * 60))
        return event
    }
}
