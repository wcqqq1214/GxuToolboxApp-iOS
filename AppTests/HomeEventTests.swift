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
    @Test(arguments: [0, 1, 7, 8, 50])
    func holidayNoticeUsesSevenCalendarDays(days: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 0, minute: 1)))
        let term = TermCalendar(startDate: calendar.startOfDay(for: now), weekCount: 20, calendar: calendar)
        let date = try #require(calendar.date(byAdding: .day, value: days, to: now))
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: date)
        let campus = CampusCalendar(holidays: [HolidayRange(title: "测试假期", from: day, to: day)])
        let blocks = CalendarOverlay.apply(to: [], calendar: campus, term: term).dayBlocks
        let holiday = try #require(NextHoliday.next(dayBlocks: blocks, term: term, now: now))
        let plan = TodayPlan.make(occurrences: [], dayBlocks: blocks, term: term, now: now)
        let event = HomeEvent.pick(plan: plan, exams: [], holiday: holiday, now: now, calendar: calendar)
        #expect(event == (days <= 7 ? .holiday(holiday) : nil))
    }

}
