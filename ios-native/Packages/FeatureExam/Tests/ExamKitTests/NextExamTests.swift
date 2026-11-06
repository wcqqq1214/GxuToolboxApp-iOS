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

struct PendingCourseTests {
    @Test func diffKeepsSelectionOrder() {
        let selected = [PendingCourse(id: "a", name: "高数"), PendingCourse(id: "b", name: "物理实验", isLab: true), PendingCourse(id: "c", name: "英语")]
        let result = PendingCourse.diff(selected: selected, scoredIds: ["a"])
        #expect(result.map(\.id) == ["b", "c"])
        #expect(result.first?.displayName == "物理实验(实验)")
        #expect(PendingCourse.diff(selected: selected, scoredIds: ["a", "b", "c"]).isEmpty)
        #expect(PendingCourse.diff(selected: [], scoredIds: ["a"]).isEmpty)
    }

    @Test func allScoresAndSliceReplace() async throws {
        let db = try AppDatabase.inMemory(features: [ExamRepository.migrations])
        let repo = ExamRepository(database: db)
        let s1 = Score(id: "1", year: 2024, term: 1, courseName: "A", credit: 2, score: 80)
        let s2 = Score(id: "2", year: 2024, term: 2, courseName: "B", credit: 2, score: 90)
        let s3 = Score(id: "3", year: 2025, term: 1, courseName: "C", credit: 2, score: 70)
        try await repo.replaceAllScores([s1, s2, s3], studentId: "x")
        try await repo.replaceAllScores([s2, s3], studentId: "y")
        #expect(try await repo.allScores(studentId: "x").count == 3)
        #expect(try await repo.allScores(studentId: "y").count == 2)
        // 同一切片里不在新响应中的行被删；响应里没出现的学期不动
        try await repo.replaceAllScores([Score(id: "4", year: 2024, term: 1, courseName: "D", credit: 1, score: 60)], studentId: "x")
        let ids = Set(try await repo.allScores(studentId: "x").map(\.id))
        #expect(ids == ["4", "2", "3"])
    }
}

struct UrgencyTests {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Shanghai")!; return c }()

    @Test func onlyTodayAndTomorrowAreUrgent() {
        let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd HH:mm"
        let now = f.date(from: "2026-01-10 08:00")!
        func item(_ t: String) -> ExamItem { ExamItem(Exam(id: t, course: "x", classroom: "", time: t, type: ""), now: now, calendar: cal) }
        #expect(item("2026-01-10(14:00-16:00)").isUrgent(now: now, calendar: cal))
        #expect(item("2026-01-11(09:00-11:00)").isUrgent(now: now, calendar: cal))
        #expect(!item("2026-01-12(09:00-11:00)").isUrgent(now: now, calendar: cal))
        #expect(!item("2026-01-19(09:00-11:00)").isUrgent(now: now, calendar: cal))
        #expect(!item("2026-01-05(09:00-11:00)").isUrgent(now: now, calendar: cal))   // 已结束
        #expect(!item("待定").isUrgent(now: now, calendar: cal))                       // 时间未知
    }
}

struct ExamTextTests {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Shanghai")!; return c }()

    @Test func seatText() {
        #expect(ExamSeat.text("8") == "8 号")
        #expect(ExamSeat.text(" 23 ") == "23 号")
        #expect(ExamSeat.text("A12") == "座位 A12")
        #expect(ExamSeat.text("") == "")
        #expect(ExamSeat.text("  ") == "")
    }

    @Test func timeLineExpressesTimeOnce() {
        let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd HH:mm"
        let now = f.date(from: "2026-01-10 08:00")!
        func line(_ t: String) -> String { ExamItem(Exam(id: t, course: "x", classroom: "", time: t, type: ""), now: now, calendar: cal).timeLine(now: now, calendar: cal) }
        #expect(line("2026-01-10(23:00-23:59)") == "23:00")          // 今日：只写钟点，日期由"今日开考"徽章表达
        #expect(line("2026-01-11(09:00-11:00)") == "09:00")          // 明日
        #expect(line("2026-01-15(14:30-16:30)") == "1月15日 14:30")  // 更远：日期 + 钟点，不再写"N天后"
        #expect(line("2026-01-05(09:00-11:00)") == "1月5日 09:00")   // 已结束
        #expect(line("待定") == "待定")
        #expect(line("") == "时间未定")
    }
}

struct NonGregorianCalendarTests {
    @Test(arguments: [Calendar.Identifier.buddhist, .japanese, .chinese, .republicOfChina, .islamicCivil])
    func examTimeIgnoresDeviceCalendarSystem(id: Calendar.Identifier) {
        var device = Calendar(identifier: id)
        device.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var g = Calendar(identifier: .gregorian)
        g.timeZone = device.timeZone
        let f = DateFormatter(); f.calendar = g; f.timeZone = g.timeZone; f.dateFormat = "yyyy-MM-dd HH:mm"
        let now = f.date(from: "2026-07-01 12:00")!
        let item = ExamItem(Exam(id: "x", course: "x", classroom: "", time: "2026-07-15(09:00-11:00)", type: ""), now: now, calendar: device)
        #expect(item.status == .upcoming)
        #expect(item.date == f.date(from: "2026-07-15 09:00"))
        #expect(item.countdownText(now: now, calendar: device) == "14天后")
        #expect(item.timeLine(now: now, calendar: device) == "7月15日 09:00")
        #expect(TermOptions.academicYear(now: now, calendar: device) == 2025)
    }
}
