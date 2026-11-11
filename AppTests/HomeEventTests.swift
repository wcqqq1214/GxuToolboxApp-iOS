import ExamKit
import Foundation
import ScheduleKit
import Testing
@testable import GxuToolApp

struct HomeEventTests {
    @Test func cachedExamStopsBeingTheNextEventAtItsEndTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        func at(_ hour: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: hour)))
        }
        let termStart = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 9)))
        let term = TermCalendar(startDate: termStart, weekCount: 20, calendar: calendar)
        let course = TheoryCourse(sectionRange: "5-6", begin: 5, end: 6, courseName: "Afternoon class", weeks: [1], weekday: 2)
        let occurrences = ScheduleExpander.occurrences(of: Schedule(theoryList: [course]), in: term)
        let afternoon = try #require(occurrences.first)
        let exam = Exam(id: "exam", course: "Morning exam", classroom: "A101", time: "2026-11-10(09:00-11:00)", type: "final")
        let loadedAt = try at(8)
        let cachedExam = ExamItem(exam, now: loadedAt, calendar: calendar)

        func pick(at time: Date) -> HomeEvent? {
            let plan = TodayPlan.make(occurrences: occurrences, dayBlocks: [], term: term, now: time)
            return HomeEvent.pick(plan: plan, exams: [cachedExam], now: time)
        }

        #expect(pick(at: loadedAt) == .exam(cachedExam, isOngoing: false))
        #expect(try pick(at: at(9)) == .exam(cachedExam, isOngoing: true))
        #expect(try pick(at: at(10)) == .exam(cachedExam, isOngoing: true))
        #expect(try pick(at: at(11)) == .course(afternoon, isOngoing: false))
        #expect(try pick(at: at(12)) == .course(afternoon, isOngoing: false))
    }
}
