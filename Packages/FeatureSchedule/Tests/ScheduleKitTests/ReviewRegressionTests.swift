import Foundation
import Testing
@testable import ScheduleKit

struct ReviewRegressionTests {
    @Test func nextRefreshNotAfterNextStarts() {
        let s = Schedule(theoryList: [course("A", weekday: 1, 1, 2, weeks: [1]), course("B", weekday: 1, 5, 6, weeks: [1])])
        let r = NextCourseCalculator.compute(schedule: s, term: term, now: at("2026-09-07 07:00"))
        #expect(r.next?.name == "A")
        #expect(r.nextRefreshAt! <= r.next!.startsAt.addingTimeInterval(1))
        let during = NextCourseCalculator.compute(schedule: s, term: term, now: at("2026-09-07 08:30"))
        #expect(during.nextRefreshAt == at("2026-09-07 09:40").addingTimeInterval(1))
    }

    @Test func impossibleDatesAreDropped() {
        #expect(TermCalendar.parseDay("2026-02-30", calendar: shanghai) == nil)
        #expect(TermCalendar.parseDay("2026-13-01", calendar: shanghai) == nil)
        #expect(TermCalendar.parseDay("2026-10-00", calendar: shanghai) == nil)
        #expect(TermCalendar.parseDay("2028-02-29", calendar: shanghai) != nil)
        #expect(TermCalendar.parseDay("2027-02-29", calendar: shanghai) == nil)
    }

    @Test func badHolidayDoesNotBlockRealDays() {
        let monday = course("M", weekday: 1, 1, 2, weeks: [1, 2, 3, 4])
        let occ = ScheduleExpander.occurrences(of: Schedule(theoryList: [monday]), in: term)
        let campus = CampusCalendar(holidays: [HolidayRange(title: "坏数据", from: "2026-09-14", to: "2026-09-31")])
        let r = CalendarOverlay.apply(to: occ, calendar: campus, term: term)
        #expect(r.occurrences.count == 4)
        #expect(r.dayBlocks.isEmpty)
    }

    @Test func sameNameConflictCanSelectSecond() {
        let a = course("自习", weekday: 1, 1, 2, venue: "A楼")
        let b = course("自习", weekday: 1, 2, 3, venue: "B楼")
        let occ = ScheduleExpander.occurrences(of: Schedule(theoryList: [a, b]), in: term)
        let group = ScheduleExpander.conflictGroups(occ)[0]
        #expect(group.items.count == 2)
        let second = group.items[1]
        let picked = group.selected(choices: [group.key: ScheduleExpander.selectionKey(second.course)])
        #expect(picked.id == second.id)
    }
}

struct WeekOfDateParityTests {
    let calendar = TermCalendar(startDate: at("2026-09-07"), weekCount: 20, calendar: shanghai)

    @Test func weekBoundaries() {
        #expect(calendar.week(containing: at("2026-09-07")) == 1)
        #expect(calendar.week(containing: at("2026-09-13")) == 1)
        #expect(calendar.week(containing: at("2026-09-14")) == 2)
        let mondays = ["2026-09-07", "2026-09-14", "2026-09-21", "2026-09-28", "2026-10-05"].map { calendar.week(containing: at($0)) }
        #expect(mondays == [1, 2, 3, 4, 5])
        #expect(calendar.week(containing: at("2026-09-06")) == 0)
        #expect(calendar.week(containing: at("2027-01-04")) == 18)
    }

    @Test func timeOfDayNeverMovesTheWeek() {
        #expect(calendar.week(containing: at("2026-09-21 23:59")) == 3)
        #expect(calendar.week(containing: at("2026-09-06 23:00")) == 0)
        let withTime = TermCalendar(TermStartDay(year: 2026, term: 1, day: "2026-09-07T08:00:00+08:00", week: 20), calendar: shanghai)
        #expect(withTime?.week(containing: at("2026-09-14")) == 2)
        #expect(withTime?.week(containing: at("2026-09-14 23:30")) == 2)
    }
}
