import ExamKit
import Foundation
import GxuFoundation
@testable import ScheduleKit
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
        let holiday = try #require(NextHoliday.next(holidays: campus.holidays, calendar: calendar, now: now))
        let plan = TodayPlan.make(occurrences: [], dayBlocks: blocks, term: term, now: now)
        let event = HomeEvent.pick(plan: plan, exams: [], holiday: holiday, now: now, calendar: calendar)
        #expect(event == (days <= 7 ? .holiday(holiday) : nil))
    }

    @Test(arguments: [11, 18, 20])
    func winterVacationReminderSurvivesTermBoundary(day: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)))
        let now = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: day, hour: 12)))
        let term = TermCalendar(startDate: start, weekCount: 19, calendar: calendar)
        let campus = CampusCalendar(holidays: [HolidayRange(title: "寒假", from: "2027-01-18", to: "2027-02-26", kind: .school)])
        let blocks = CalendarOverlay.apply(to: [], calendar: campus, term: term).dayBlocks
        #expect(blocks.isEmpty)
        let snapshot = ScheduleSnapshot(term: AcademicTerm(year: 2026, term: 1), termCalendar: term,
                                        schedule: Schedule(theoryList: []), campus: campus, choices: [:], activities: [],
                                        occurrences: [], dayBlocks: blocks, updatedAt: now)
        let event = HomeEvent.pick(snapshot: snapshot, exams: [], now: now)
        guard case .holiday(let holiday) = event else {
            Issue.record("跨学期寒假应提前 7 天出现，实际没有假期提示")
            return
        }
        #expect(holiday.title == "寒假")
    }

    @Test(arguments: ["2027-01-10", "2027-01-11", "2027-01-18", "2027-02-26", "2027-02-27",
                      "2027-07-04", "2027-07-05", "2027-07-12", "2027-08-27", "2027-08-28"])
    func vacationsDoNotRequireAScheduleSnapshot(day: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let now = try #require(formatter.date(from: day))
        let campus = CampusCalendar(holidays: [
            HolidayRange(title: "寒假", from: "2027-01-18", to: "2027-02-26", kind: .school),
            HolidayRange(title: "暑假", from: "2027-07-12", to: "2027-08-27", kind: .school),
        ])
        let event = HomeEvent.pick(snapshot: nil, campus: campus, exams: [], now: now, calendar: calendar)
        if ["2027-01-10", "2027-02-27", "2027-07-04", "2027-08-28"].contains(day) {
            #expect(event == nil)
        } else {
            guard case .holiday(let holiday) = event else { Issue.record("应显示寒暑假提示"); return }
            let ongoing = ["2027-01-18", "2027-02-26", "2027-07-12", "2027-08-27"].contains(day)
            #expect(event?.isOngoing == ongoing)
            #expect(holiday.displayTitle == (day < "2027-07-01" ? (ongoing ? "寒假中" : "寒假") : (ongoing ? "暑假中" : "暑假")))
        }
    }

    @Test func ongoingExamTakesPriorityOverVacation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let now = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 20, hour: 12)))
        let holiday = try #require(NextHoliday.next(holidays: [HolidayRange(title: "寒假", from: "2027-01-18", to: "2027-02-26", kind: .school)], calendar: calendar, now: now))
        let exam = ExamItem(Exam(id: "exam", course: "考试", classroom: "A101", time: "2027-01-20(11:00-13:00)", type: "final"), now: now, calendar: calendar)
        #expect(HomeEvent.pick(plan: nil, exams: [exam], holiday: holiday, now: now, calendar: calendar) == .exam(exam, isOngoing: true))
    }

    @Test func ongoingCourseTakesPriorityOverVacation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let start = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 18)))
        let now = try #require(calendar.date(bySettingHour: 8, minute: 15, second: 0, of: start))
        let term = TermCalendar(startDate: start, weekCount: 1, calendar: calendar)
        let course = TheoryCourse(sectionRange: "1-2", begin: 1, end: 2, courseName: "假期课程", weeks: [1], weekday: 1)
        let occurrences = ScheduleExpander.occurrences(of: Schedule(theoryList: [course]), in: term)
        let current = try #require(occurrences.first)
        let plan = TodayPlan.make(occurrences: occurrences, dayBlocks: [], term: term, now: now)
        let holiday = try #require(NextHoliday.next(holidays: [HolidayRange(title: "寒假", from: "2027-01-18", to: "2027-02-26", kind: .school)], calendar: calendar, now: now))
        #expect(HomeEvent.pick(plan: plan, exams: [], holiday: holiday, now: now, calendar: calendar) == .course(current, isOngoing: true))
    }

    @Test func nextEventAccessoryIsOnlyAvailableOnScheduleTab() {
        #expect(AppTab.schedule.showsNextEventAccessory)
        #expect(!AppTab.home.showsNextEventAccessory)
        #expect(!AppTab.toolbox.showsNextEventAccessory)
        #expect(!AppTab.settings.showsNextEventAccessory)
    }

}
