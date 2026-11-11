import Foundation
import Testing
@testable import ScheduleKit

struct WeekAndCalendarTests {
    @Test func parsesRangesSingleAndParity() {
        #expect(WeekParser.parse("1-4周,6-9周,11-14周") == [1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14])
        #expect(WeekParser.parse("1-16周(单)") == [1, 3, 5, 7, 9, 11, 13, 15])
        #expect(WeekParser.parse("2-8周(双)") == [2, 4, 6, 8])
        #expect(WeekParser.parse("5周") == [5])
        #expect(WeekParser.parse("3-5周,4-6周") == [3, 4, 5, 6])
        #expect(WeekParser.parse("") == [])
        #expect(WeekParser.parse("abc,8-,x-3") == [])
    }

    @Test func weekNumbersAroundTermBoundaries() {
        #expect(term.week(containing: at("2026-09-07")) == 1)
        #expect(term.week(containing: at("2026-09-13 23:59")) == 1)
        #expect(term.week(containing: at("2026-09-14")) == 2)
        #expect(term.week(containing: at("2026-09-06")) == 0)
        #expect(term.week(containing: at("2026-08-01")) < 0)
        #expect(term.isStarted(at: at("2026-09-06")) == false)
        #expect(term.isEnded(at: at("2027-01-10")) == false)
        #expect(term.isEnded(at: at("2027-01-11")) == true)
        #expect(term.clampedWeek(at: at("2026-01-01")) == 1)
        #expect(term.clampedWeek(at: at("2027-06-01")) == 18)
    }

    @Test func dateAndWeekdayMapping() {
        #expect(term.date(week: 1, weekday: 1) == at("2026-09-07"))
        #expect(term.date(week: 2, weekday: 7) == at("2026-09-20"))
        #expect(term.weekday(of: at("2026-09-07")) == 1)
        #expect(term.weekday(of: at("2026-09-13")) == 7)
    }

    @Test func parsesDayStringsWithAndWithoutTimeZone() {
        func parsed(_ s: String) -> Date? { TermCalendar.parseDay(s, calendar: shanghai) }
        #expect(parsed("2026-09-07") == at("2026-09-07"))
        #expect(parsed("2026-09-07T00:00:00+08:00") == at("2026-09-07"))
        #expect(parsed("2026-09-06T16:00:00.000Z") == at("2026-09-07"))
        #expect(parsed("garbage") == nil)
    }

    @Test func utcMidnightMeansCalendarDayInAnyTimeZone() {
        for zone in ["Asia/Shanghai", "America/Los_Angeles", "Pacific/Auckland", "UTC"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zone)!
            let expected = calendar.date(from: DateComponents(year: 2024, month: 8, day: 26))!
            #expect(TermCalendar.parseDay("2024-08-26T00:00:00.000Z", calendar: calendar) == expected, "\(zone)")
            #expect(TermCalendar.parseDay("2024-08-26T00:00:00Z", calendar: calendar) == expected, "\(zone)")
        }
    }

    @Test func resolvesCurrentTermIgnoringBackendFlag() {
        let autumn = TermStartDay(year: 2025, term: 1, day: "2025-09-08", week: 18, isCurrent: true)
        let spring = TermStartDay(year: 2026, term: 2, day: "2026-03-02", week: 18)
        let next = TermStartDay(year: 2026, term: 1, day: "2026-09-07", week: 18)
        let all = [next, autumn, spring]
        #expect(TermResolver.current(in: all, now: at("2025-10-01"), calendar: shanghai) == autumn)
        #expect(TermResolver.current(in: all, now: at("2026-03-10"), calendar: shanghai) == spring)
        #expect(TermResolver.current(in: all, now: at("2026-08-01"), calendar: shanghai) == next)
        #expect(TermResolver.current(in: all, now: at("2028-01-01"), calendar: shanghai) == next)
        #expect(TermResolver.current(in: [], now: .now) == nil)
    }
}
