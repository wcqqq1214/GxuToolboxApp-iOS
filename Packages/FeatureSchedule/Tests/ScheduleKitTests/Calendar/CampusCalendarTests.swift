import Foundation
import GxuFoundation
import GxuStorage
import Testing
@testable import ScheduleKit

struct CampusCalendarTests {
    // term：2026-09-07（周一）开学。9-21 周一、9-25 周五、9-27 周日；10-01 国庆在第 5 周周四
    let friday = course("高等数学", weekday: 5, 1, 2, weeks: Array(1...18))
    let monday = course("大学英语", weekday: 1, 3, 4, weeks: Array(1...18))

    private func expand(_ courses: [TheoryCourse]) -> [CourseOccurrence] {
        ScheduleExpander.occurrences(of: Schedule(theoryList: courses), in: term)
    }

    @Test func holidayKeepsCoursesAndAddsDayBlocks() {
        // RN v2.2：假期是一层底部横幅（假期图层 needShift: false），课程照常保留
        let campus = CampusCalendar(holidays: [HolidayRange(title: "中秋节", from: "2026-09-25", to: "2026-09-27")])
        let result = CalendarOverlay.apply(to: expand([friday]), calendar: campus, term: term)
        // 9-25 是周五，第 3 周
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
        // 周日 9-20 补 10-06（周二，第 5 周）的课；周二没课时用周二的课
        let tuesday = course("线性代数", weekday: 2, 1, 2, weeks: Array(1...18))
        let campus = CampusCalendar(timeShift: [ShiftRule(workDate: "2026-09-20", restDate: "2026-10-06")])
        let result = CalendarOverlay.apply(to: expand([tuesday]), calendar: campus, term: term)

        let moved = try #require(result.occurrences.first { $0.isMakeup })
        #expect(moved.date == at("2026-09-20"))
        #expect(moved.week == 2 && moved.weekday == 7)
        #expect(moved.shiftedFrom == at("2026-10-06"))
        #expect(moved.startsAt == at("2026-09-20 08:30") || moved.startsAt == at("2026-09-20 08:00"))
        // 休息日那天的课被移走，且休息日不在假期里，所以有一个“调休”整天块
        #expect(!result.occurrences.contains { $0.date == at("2026-10-06") })
        let rest = try #require(result.dayBlocks.first)
        #expect(rest.kind == .rest && rest.week == 5 && rest.weekday == 2)
    }

    @Test func makeupDayKeepsItsOwnRegularCourses() {
        // 9-21 是周一，补 9-25（周五）的课：RN v2.2 保留周一原有的课，两组并排
        let campus = CampusCalendar(timeShift: [ShiftRule(workDate: "2026-09-21", restDate: "2026-09-25")])
        let result = CalendarOverlay.apply(to: expand([monday, friday]), calendar: campus, term: term)
        let onDay = result.occurrences.filter { $0.date == at("2026-09-21") }
        #expect(Set(onDay.map(\.course.courseName)) == ["大学英语", "高等数学"])
        #expect(onDay.filter(\.isMakeup).map(\.course.courseName) == ["高等数学"])
    }

    @Test func makeupAndOwnCoursesAreSeparateConflictDomains() {
        // 补课项和原有的课时间重叠也不算同一个冲突组：各自选各自的
        let own = course("线性代数", weekday: 1, 1, 2, weeks: Array(1...18))
        let campus = CampusCalendar(timeShift: [ShiftRule(workDate: "2026-09-21", restDate: "2026-09-25")])
        let result = CalendarOverlay.apply(to: expand([own, friday]), calendar: campus, term: term)
        let onDay = result.occurrences.filter { $0.date == at("2026-09-21") }
        #expect(onDay.count == 2)                                         // 都是第 1-2 节，时间重叠
        #expect(ConflictResolver.resolve(onDay, choices: [:]).count == 2) // 但不是同一个冲突域，两门都保留
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
        #expect(!calendar.holidays.isEmpty)   // 内置备份
    }

    @Test func bundledFallbackIsValid() {
        let fallback = CampusCalendarFile.fallback
        #expect((fallback.timeShift?.count ?? 0) > 0)
        #expect((fallback.holidays?.count ?? 0) > 0)
    }

    // MARK: 仓库

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
    // 中秋 9-25…9-27（周五到周日），国庆 10-01…10-07
    private func blocks() -> [DayBlock] {
        let campus = CampusCalendar(
            timeShift: [ShiftRule(workDate: "2026-09-20", restDate: "2026-09-28")],
            holidays: [HolidayRange(title: "中秋节", from: "2026-09-25", to: "2026-09-27"), HolidayRange(title: "国庆节", from: "2026-10-01", to: "2026-10-07")]
        )
        return CalendarOverlay.apply(to: [], calendar: campus, term: term).dayBlocks
    }

    @Test func picksFirstHolidayDayAfterNow() throws {
        let next = try #require(NextHoliday.next(dayBlocks: blocks(), term: term, now: at("2026-09-16 09:00")))
        #expect(next.title == "中秋节" && next.date == at("2026-09-25") && next.startsAt == at("2026-09-25 08:00"))
        #expect(next.dayText(now: at("2026-09-16 09:00"), calendar: shanghai) == "9 天后")
    }

    @Test func insideMultiDayHolidayPointsToNextDay() throws {
        // 9-25 早上八点之后，今天的假期日已经开始，下一个是 9-26
        let next = try #require(NextHoliday.next(dayBlocks: blocks(), term: term, now: at("2026-09-25 09:00")))
        #expect(next.date == at("2026-09-26"))
        #expect(next.dayText(now: at("2026-09-25 09:00"), calendar: shanghai) == "明天")
    }

    @Test func beforeEightOnHolidayItIsToday() throws {
        let next = try #require(NextHoliday.next(dayBlocks: blocks(), term: term, now: at("2026-09-25 07:00")))
        #expect(next.dayText(now: at("2026-09-25 07:00"), calendar: shanghai) == "今天")
    }

    @Test func restDaysAreNotHolidays() {
        // 9-28 是调休休息日，不算“下个假期”
        let next = NextHoliday.next(dayBlocks: blocks(), term: term, now: at("2026-09-27 09:00"))
        #expect(next?.title == "国庆节")
    }

    @Test func noneAfterLastHoliday() {
        #expect(NextHoliday.next(dayBlocks: blocks(), term: term, now: at("2026-10-08 09:00")) == nil)
    }
}
