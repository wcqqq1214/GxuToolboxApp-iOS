import Foundation
import Testing
@testable import ScheduleKit

struct NonGregorianCalendarTests {
    private static let identifiers: [Calendar.Identifier] = [.buddhist, .japanese, .islamicUmmAlQura, .republicOfChina, .hebrew]

    private func device(_ id: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: id)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    @Test func termStartDayIsGregorianRegardlessOfDeviceCalendar() throws {
        let expected = at("2026-09-07")
        for id in Self.identifiers {
            let termCalendar = try #require(TermCalendar(TermStartDay(year: 2026, term: 1, day: "2026-09-07", week: 18), calendar: device(id)))
            #expect(termCalendar.startDate == expected, "\(id)")
            #expect(termCalendar.calendar.identifier == .gregorian)
            #expect(termCalendar.week(containing: at("2026-09-16")) == 2, "\(id)")
            #expect(termCalendar.weekday(of: at("2026-09-16")) == 3, "\(id)")
            #expect(termCalendar.date(week: 2, weekday: 3) == at("2026-09-16"), "\(id)")
        }
    }

    @Test func isoStartDaysAndImpossibleDatesStillBehave() {
        for id in Self.identifiers {
            let calendar = device(id)
            #expect(TermCalendar.parseDay("2024-08-26T00:00:00.000Z", calendar: calendar) == at("2024-08-26"), "\(id)")
            #expect(TermCalendar.parseDay("2026-09-06T16:00:00.000Z", calendar: calendar) == at("2026-09-07"), "\(id)")
            #expect(TermCalendar.parseDay("2026-02-30", calendar: calendar) == nil, "\(id)")
        }
    }

    @Test func termResolverAndOverlayUseGregorian() throws {
        let days = [TermStartDay(year: 2026, term: 1, day: "2026-09-07", week: 18)]
        let campus = CampusCalendar(
            timeShift: [ShiftRule(workDate: "2026-09-20", restDate: "2026-09-25")],
            holidays: [HolidayRange(title: "中秋节", from: "2026-09-25", to: "2026-09-27")]
        )
        for id in Self.identifiers {
            let calendar = device(id)
            #expect(TermResolver.current(in: days, now: at("2026-10-01"), calendar: calendar)?.year == 2026, "\(id)")
            let termCalendar = try #require(TermCalendar(days[0], calendar: calendar))
            let friday = course("高等数学", weekday: 5, 1, 2, weeks: Array(1...18))
            let occurrences = ScheduleExpander.occurrences(of: Schedule(theoryList: [friday]), in: termCalendar)
            let result = CalendarOverlay.apply(to: occurrences, calendar: campus, term: termCalendar)
            #expect(result.dayBlocks.map(\.weekday) == [5, 6, 7], "\(id)")
            #expect(result.occurrences.contains { $0.isMakeup && $0.date == at("2026-09-20") }, "\(id)")
        }
    }

    @Test func widgetDateKeyIsGregorianYear() {
        for id in Self.identifiers {
            #expect(WidgetCourse.dateKey(at("2026-09-07"), calendar: device(id)) == "2026-09-07", "\(id)")
        }
    }
}


extension NonGregorianCalendarTests {
    @Test func ignoresOutOfRangeAcademicWeeks() throws {
        let input = Data(#"[{"year":2026,"term":1,"day":"2026-09-07","week":9223372036854775807},{"year":2026,"term":2,"day":"2027-03-01","week":20}]"#.utf8)
        let terms = try JSONDecoder().decode([TermStartDay].self, from: input)
        #expect(TermCalendar(terms[0], calendar: shanghai) == nil)
        #expect(TermResolver.current(in: terms, now: at("2026-09-07"), calendar: shanghai) == terms[1])
        let normal = try #require(TermCalendar(terms[1], calendar: shanghai))
        let mixed = course("测试课", weekday: 1, 1, 2, weeks: [1, Int.max])
        #expect(ScheduleExpander.occurrences(of: Schedule(theoryList: [mixed]), in: normal).map(\.week) == [1])
    }
}
