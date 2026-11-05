import Foundation
import Testing
@testable import ScheduleKit

struct NextCourseTests {
    private func compute(_ schedule: Schedule, now: String) -> NextCourses {
        NextCourseCalculator.compute(schedule: schedule, term: term, now: at(now))
    }

    private let week = Schedule(theoryList: [
        course("周一上午", weekday: 1, 1, 2, weeks: [1, 2]),
        course("周一下午", weekday: 1, 5, 6, weeks: [1, 2]),
        course("周二上午", weekday: 2, 3, 4, weeks: [1]),
        course("周日晚上", weekday: 7, 11, 12, weeks: [1]),
    ])

    @Test func beforeFirstClassOfTheDay() throws {
        let result = compute(week, now: "2026-09-07 07:00")
        #expect(result.state == .ready)
        #expect(result.today.map(\.name) == ["周一上午", "周一下午"])
        #expect(result.tomorrow.map(\.name) == ["周二上午"])
        #expect(result.next?.name == "周一上午")
        #expect(result.next?.beginTime == "08:00" && result.next?.endTime == "09:40")
        #expect(result.nextRefreshAt == at("2026-09-07 09:40").addingTimeInterval(1))
    }

    @Test func classInProgressIsTodayButNotNext() {
        let result = compute(week, now: "2026-09-07 08:30")
        #expect(result.today.map(\.name) == ["周一上午", "周一下午"])
        #expect(result.next?.name == "周一下午")
    }

    @Test func afterLastClassOfTheDayRollsToNextOccurrence() {
        let result = compute(week, now: "2026-09-07 17:00")
        #expect(result.today.isEmpty)
        #expect(result.next?.name == "周二上午")
        #expect(result.next?.date == "2026-09-08")
        // 今天没有课了：下次刷新取到次日 00:00:01 与下一个课结束时间中的较早者
        #expect(result.nextRefreshAt == at("2026-09-08").addingTimeInterval(1))
    }

    @Test func sundayDoesNotJumpToNextWeek() {
        // RN 旧实现用 moment().day(7) 会在周日算到下一周
        let result = compute(week, now: "2026-09-13 09:00")
        #expect(result.today.map(\.name) == ["周日晚上"])
        #expect(result.next?.name == "周日晚上")
        #expect(result.tomorrow.map(\.name) == ["周一上午", "周一下午"])   // 第 2 周周一
    }

    @Test func crossesWeekBoundary() {
        let result = compute(week, now: "2026-09-13 21:30")
        #expect(result.today.isEmpty)
        #expect(result.next?.name == "周一上午")
        #expect(result.next?.date == "2026-09-14")
    }

    @Test func beforeTermStartsAndAfterTermEnds() {
        let before = compute(week, now: "2026-08-30 10:00")
        #expect(before.state == .ready && before.today.isEmpty)
        #expect(before.next?.date == "2026-09-07")
        let after = compute(week, now: "2027-02-01 10:00")
        #expect(after.state == .ready && after.next == nil && after.today.isEmpty)
    }

    @Test func overlappingPeriodsBothShowAsToday() {
        // 第 9 节 18:10-18:55 与第 10 节 18:45-19:30 在作息上本就重叠
        let schedule = Schedule(theoryList: [course("九", 9, 9), course("十", 10, 10)])
        let result = compute(schedule, now: "2026-09-07 18:50")
        #expect(result.today.map(\.name) == ["九", "十"])
        #expect(result.next == nil)
    }

    @Test func missingInputs() {
        #expect(NextCourseCalculator.compute(schedule: nil, term: term, now: .now).state == .missingSchedule)
        #expect(NextCourseCalculator.compute(schedule: week, term: nil, now: .now).state == .missingStartDay)
    }
}
