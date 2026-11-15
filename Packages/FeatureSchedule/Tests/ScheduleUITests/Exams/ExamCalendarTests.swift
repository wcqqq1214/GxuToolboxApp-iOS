import EventKit
import Foundation
import ScheduleKit
import Testing
@testable import ScheduleUI

@MainActor
struct ExamCalendarTests {
    @Test func copiesExamDetailsWithoutSaving() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let exam = GridExam(id: "exam", title: " 高等数学 ", location: " 西3-406 ", seat: "23号", kind: "期末考试", start: start, end: start.addingTimeInterval(7200))
        let draft = try #require(ExamCalendarEvent(exam: exam))
        let event = draft.makeEvent(in: EKEventStore())
        let notes = try #require(event.notes)
        #expect(event.title == "高等数学 · 考试")
        #expect(event.startDate == exam.start)
        #expect(event.endDate == exam.end)
        #expect(event.location == "西3-406")
        #expect(notes.contains("座位：23号"))
        #expect(notes.contains("类别：期末考试"))
        #expect(notes.contains("手动更新"))
        #expect(!event.isAllDay)
        #expect(event.alarms?.first?.relativeOffset == -1800)
        #expect(event.eventIdentifier == nil)
    }

    @Test func missingDetailsAndInvalidIntervals() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var exam = GridExam(id: "exam", title: "  ", start: start, end: start)
        #expect(ExamCalendarEvent(exam: exam) == nil)
        exam.end = start.addingTimeInterval(-60)
        #expect(ExamCalendarEvent(exam: exam) == nil)
        exam.end = start.addingTimeInterval(3600)
        let event = try #require(ExamCalendarEvent(exam: exam)).makeEvent(in: EKEventStore())
        let notes = try #require(event.notes)
        #expect(event.title == "考试")
        #expect(event.location == nil)
        #expect(!notes.contains("座位"))
    }
}
