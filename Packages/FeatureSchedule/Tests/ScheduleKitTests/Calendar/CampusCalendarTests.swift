import Foundation
import GxuFoundation
import GxuStorage
import Testing
@testable import ScheduleKit

struct CampusCalendarTests {
    let friday = course("高等数学", weekday: 5, 1, 2, weeks: Array(1...18))
    let monday = course("大学英语", weekday: 1, 3, 4, weeks: Array(1...18))

    private func expand(_ courses: [TheoryCourse]) -> [CourseOccurrence] {
        ScheduleExpander.occurrences(of: Schedule(theoryList: courses), in: term)
    }

    @Test func holidayKeepsCoursesAndAddsDayBlocks() {
        let campus = CampusCalendar(holidays: [HolidayRange(title: "中秋节", from: "2026-09-25", to: "2026-09-27")])
        let result = CalendarOverlay.apply(to: expand([friday]), calendar: campus, term: term)
        #expect(result.occurrences.contains { $0.date == at("2026-09-25") })
        #expect(result.occurrences.filter { $0.course.courseName == "高等数学" }.count == 18)
        #expect(result.dayBlocks.map(\.weekday) == [5, 6, 7])
        #expect(result.dayBlocks.map(\.isFirstDay) == [true, false, false])
        #expect(result.dayBlocks.allSatisfy { $0.week == 3 && $0.title == "中秋节" })
    }

    @Test func restDayStillRemovesCourses() {
        let campus = CampusCalendar(timeShift: [ShiftRule(workDate: "2026-09-20", restDate: "2026-09-25")])
        let result = CalendarOverlay.apply(to: expand([friday]), calendar: campus, term: term)
        #expect(!result.occurrences.contains { $0.date == at("2026-09-25") })
    }

    @Test func makeupDayShowsRestDayCoursesWithMarker() throws {
        let tuesday = course("线性代数", weekday: 2, 1, 2, weeks: Array(1...18))
        let campus = CampusCalendar(timeShift: [ShiftRule(workDate: "2026-09-20", restDate: "2026-10-06")])
        let result = CalendarOverlay.apply(to: expand([tuesday]), calendar: campus, term: term)

        let moved = try #require(result.occurrences.first { $0.isMakeup })
        #expect(moved.date == at("2026-09-20"))
        #expect(moved.week == 2 && moved.weekday == 7)
        #expect(moved.shiftedFrom == at("2026-10-06"))
        #expect(moved.startsAt == at("2026-09-20 08:30") || moved.startsAt == at("2026-09-20 08:00"))
        #expect(!result.occurrences.contains { $0.date == at("2026-10-06") })
        let rest = try #require(result.dayBlocks.first)
        #expect(rest.kind == .rest && rest.week == 5 && rest.weekday == 2)
    }

    @Test func makeupDayKeepsItsOwnRegularCourses() {
        let campus = CampusCalendar(timeShift: [ShiftRule(workDate: "2026-09-21", restDate: "2026-09-25")])
        let result = CalendarOverlay.apply(to: expand([monday, friday]), calendar: campus, term: term)
        let onDay = result.occurrences.filter { $0.date == at("2026-09-21") }
        #expect(Set(onDay.map(\.course.courseName)) == ["大学英语", "高等数学"])
        #expect(onDay.filter(\.isMakeup).map(\.course.courseName) == ["高等数学"])
    }

    @Test func makeupAndOwnCoursesAreSeparateConflictDomains() {
        let own = course("线性代数", weekday: 1, 1, 2, weeks: Array(1...18))
        let campus = CampusCalendar(timeShift: [ShiftRule(workDate: "2026-09-21", restDate: "2026-09-25")])
        let result = CalendarOverlay.apply(to: expand([own, friday]), calendar: campus, term: term)
        let onDay = result.occurrences.filter { $0.date == at("2026-09-21") }
        #expect(onDay.count == 2)
        #expect(ConflictResolver.resolve(onDay, choices: [:]).count == 2)
    }

    @Test func makeupIdsAreUniqueFromRegular() {
        let campus = CampusCalendar(timeShift: [ShiftRule(workDate: "2026-09-20", restDate: "2026-09-25")])
        let result = CalendarOverlay.apply(to: expand([friday]), calendar: campus, term: term)
        #expect(Set(result.occurrences.map(\.id)).count == result.occurrences.count)
    }

    @Test func emptyCalendarChangesNothing() {
        let all = expand([friday, monday])
        let result = CalendarOverlay.apply(to: all, calendar: .empty, term: term)
        #expect(result.occurrences == all)
        #expect(result.dayBlocks.isEmpty)
    }

    @Test func datesOutsideTermAreIgnored() {
        let campus = CampusCalendar(holidays: [HolidayRange(title: "清明节", from: "2027-04-04", to: "2027-04-06")])
        #expect(CalendarOverlay.apply(to: expand([friday]), calendar: campus, term: term).dayBlocks.isEmpty)
    }

    @Test func badDataDoesNotCrash() {
        let campus = CampusCalendar(
            timeShift: [ShiftRule(workDate: "bad", restDate: "2026-09-25")],
            holidays: [HolidayRange(title: "反了", from: "2026-09-27", to: "2026-09-25")]
        )
        #expect(CalendarOverlay.apply(to: expand([friday]), calendar: campus, term: term).occurrences.count == 18)
    }

    @Test func decodesRemoteFileAndSkipsBadEntries() throws {
        let json = #"{"timeShift": [["2026-09-20","2026-10-06"], ["only-one"]], "holidays": [{"title":"国庆节","from":"2026-10-01","to":"2026-10-07"}, {"title":"缺字段"}]}"#
        let file = try JSONDecoder().decode(CampusCalendarFile.self, from: Data(json.utf8))
        #expect(file.timeShift == [ShiftRule(workDate: "2026-09-20", restDate: "2026-10-06")])
        #expect(file.holidays?.count == 1)
        #expect(file.holidays?.first?.kind == .national)
    }

    @Test func legacyFileWithOnlyTimeShiftKeepsFallbackHolidays() throws {
        let file = try JSONDecoder().decode(CampusCalendarFile.self, from: Data(#"{"timeShift": []}"#.utf8))
        let calendar = file.resolved(updatedAt: nil)
        #expect(calendar.timeShift.isEmpty)
        #expect(!calendar.holidays.isEmpty)
    }

    @Test func legacyRemoteKeepsSchoolVacationsAfterCaching() async throws {
        let repository = try makeRepository { _ in Data(#"{"timeShift": []}"#.utf8) }
        _ = try await repository.refresh()
        let calendar = await repository.current()
        let winter = calendar.holidays.first { $0.title == "寒假" }
        let summer = calendar.holidays.first { $0.title == "暑假" }
        #expect(winter == HolidayRange(title: "寒假", from: "2027-01-18", to: "2027-02-26", kind: .school))
        #expect(summer == HolidayRange(title: "暑假", from: "2027-07-12", to: "2027-08-27", kind: .school))
    }

    @Test func bundledFallbackIsValid() {
        let fallback = CampusCalendarFile.fallback
        #expect((fallback.timeShift?.count ?? 0) > 0)
        #expect((fallback.holidays?.count ?? 0) > 0)
    }


    private func makeRepository(_ fetch: @escaping CampusCalendarRepository.Fetch) throws -> CampusCalendarRepository {
        CampusCalendarRepository(database: try .inMemory(features: [ScheduleKit.migrations]), fetch: fetch)
    }

    @Test func repositoryFallsBackThenCachesRemote() async throws {
        let body = #"{"timeShift": [["2030-01-05","2030-01-03"]], "holidays": []}"#
        let repository = try makeRepository { _ in Data(body.utf8) }

        let before = await repository.current()
        #expect(before.updatedAt == nil)
        #expect(!before.holidays.isEmpty)

        let refreshed = try await repository.refresh(now: at("2026-11-05"))
        #expect(refreshed.timeShift == [ShiftRule(workDate: "2030-01-05", restDate: "2030-01-03")])
        #expect(refreshed.holidays.isEmpty)

        let after = await repository.current()
        #expect(after == refreshed)
        #expect(after.updatedAt == at("2026-11-05"))
    }

    @Test func failedRefreshKeepsCache() async throws {
        let counter = Counter()
        let repository = try makeRepository { _ in
            if await counter.next() == 1 { return Data(#"{"timeShift": [["2030-01-05","2030-01-03"]]}"#.utf8) }
            throw GxuError.network("offline")
        }
        let first = try await repository.refresh()
        await #expect(throws: GxuError.self) { try await repository.refresh() }
        #expect(await repository.current().timeShift == first.timeShift)
    }

    @Test func invalidPayloadIsRejected() async throws {
        for body in ["<html>", "{}", "[]"] {
            let repository = try makeRepository { _ in Data(body.utf8) }
            await #expect(throws: GxuError.self) { try await repository.refresh() }
            #expect(await repository.current().updatedAt == nil)
        }
    }
}

private actor Counter {
    private var value = 0
    func next() -> Int { value += 1; return value }
}

struct NextHolidayTests {
    private let holidays = [
        HolidayRange(title: "寒假", from: "2027-01-18", to: "2027-02-26", kind: .school),
        HolidayRange(title: "春节", from: "2027-02-05", to: "2027-02-13"),
        HolidayRange(title: "暑假", from: "2027-07-12", to: "2027-08-27", kind: .school),
    ]

    @Test func upcomingVacationUsesItsStartDate() throws {
        let next = try #require(NextHoliday.next(holidays: holidays, calendar: shanghai, now: at("2027-01-11 23:59")))
        #expect(next.title == "寒假")
        #expect(next.status == .upcoming)
        #expect(next.date == at("2027-01-18"))
        #expect(next.dayText(now: at("2027-01-11 23:59"), calendar: shanghai) == "7 天后")
    }

    @Test(arguments: ["2027-01-18 00:00", "2027-01-18 09:00", "2027-02-06 12:00", "2027-02-26 23:59"])
    func winterVacationIncludesBothBoundaryDaysAndOverlappingSpringFestival(time: String) throws {
        let next = try #require(NextHoliday.next(holidays: holidays, calendar: shanghai, now: at(time)))
        #expect(next.title == "寒假")
        #expect(next.status == .ongoing)
        #expect(next.displayTitle == "寒假中")
        #expect(next.dayText(now: at(time), calendar: shanghai) == "放假中")
    }

    @Test(arguments: ["2027-07-12 00:00", "2027-08-27 23:59"])
    func summerVacationIncludesBothBoundaryDays(time: String) throws {
        let next = try #require(NextHoliday.next(holidays: holidays, calendar: shanghai, now: at(time)))
        #expect(next.status == .ongoing)
        #expect(next.displayTitle == "暑假中")
    }

    @Test func expiredAndInvalidRangesDoNotBecomeReminders() {
        #expect(NextHoliday.next(holidays: holidays, calendar: shanghai, now: at("2027-02-27"))?.title == "暑假")
        #expect(NextHoliday.next(holidays: holidays, calendar: shanghai, now: at("2027-08-28")) == nil)
        let invalid = [HolidayRange(title: "无效", from: "bad", to: "2027-01-01"),
                       HolidayRange(title: "倒置", from: "2027-02-01", to: "2027-01-01")]
        #expect(NextHoliday.next(holidays: invalid, calendar: shanghai, now: at("2027-01-01")) == nil)
        #expect(NextHoliday.next(holidays: [], calendar: shanghai, now: at("2027-01-01")) == nil)
    }
}
