import Foundation
import GxuFoundation
import GxuStorage
import Testing
@testable import ExamKit

struct NextExamTests {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Shanghai")!; return c }()
    func date(_ s: String) -> Date {
        let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }
    func exam(_ id: String, _ time: String) -> Exam { Exam(id: id, course: id, classroom: "A101", time: time, type: "期末") }

    @Test func picksEarliestUnfinished() {
        let now = date("2026-01-10 08:00")
        let items = [exam("c", "2026-01-23(09:00-11:00)"), exam("a", "2026-01-12(14:00-16:00)"), exam("past", "2026-01-05(09:00-11:00)"), exam("tbd", "待定")]
            .map { ExamItem($0, now: now, calendar: cal) }
        #expect(NextExam.pick(from: items)?.id == "a")
        #expect(NextExam.upcoming(in: items).map(\.id) == ["a", "c"])
    }

    @Test func inProgressStillCounts() {
        let now = date("2026-01-12 15:00")
        let items = [exam("a", "2026-01-12(14:00-16:00)")].map { ExamItem($0, now: now, calendar: cal) }
        #expect(NextExam.pick(from: items)?.id == "a")
    }

    @Test func noneWhenAllPastOrUnknown() {
        let now = date("2026-02-01 08:00")
        let items = [exam("a", "2026-01-12(14:00-16:00)"), exam("b", "")].map { ExamItem($0, now: now, calendar: cal) }
        #expect(NextExam.pick(from: items) == nil)
    }

    @Test func repositoryScansAllTermsForOneStudent() async throws {
        let db = try AppDatabase.inMemory(features: [ExamRepository.migrations])
        let repo = ExamRepository(database: db)
        let now = date("2026-01-10 08:00")
        try await repo.replaceExams([exam("far", "2026-06-20(09:00-11:00)")], studentId: "s1", term: AcademicTerm(year: 2025, term: 2), now: now)
        try await repo.replaceExams([exam("near", "2026-01-15(09:00-11:00)")], studentId: "s1", term: AcademicTerm(year: 2025, term: 1), now: now)
        try await repo.replaceExams([exam("other", "2026-01-11(09:00-11:00)")], studentId: "s2", term: AcademicTerm(year: 2025, term: 1), now: now)
        #expect(try await repo.nextExam(studentId: "s1", now: now, calendar: cal)?.id == "near")
        #expect(try await repo.upcomingExams(studentId: "s1", limit: 5, now: now, calendar: cal).map(\.id) == ["near", "far"])
        #expect(try await repo.nextExam(studentId: "none", now: now, calendar: cal) == nil)
    }
}
