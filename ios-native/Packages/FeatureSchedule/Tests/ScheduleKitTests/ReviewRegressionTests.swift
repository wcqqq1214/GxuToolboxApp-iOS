import Foundation
import Testing
@testable import ScheduleKit

/// pstack interrogate 审查（第 1 轮）里被运行证明的 bug 的回归测试
struct ReviewRegressionTests {
    /// `nextRefreshAt` 不能晚于“下一节课开始”：08:00 之后 `next` 就不再是它
    @Test func nextRefreshNotAfterNextStarts() {
        let s = Schedule(theoryList: [course("A", weekday: 1, 1, 2, weeks: [1]), course("B", weekday: 1, 5, 6, weeks: [1])])
        let r = NextCourseCalculator.compute(schedule: s, term: term, now: at("2026-09-07 07:00"))
        #expect(r.next?.name == "A")
        #expect(r.nextRefreshAt! <= r.next!.startsAt.addingTimeInterval(1))
        // 正在上课时，下一次变化是这节课结束和下一节课开始里更早的
        let during = NextCourseCalculator.compute(schedule: s, term: term, now: at("2026-09-07 08:30"))
        #expect(during.nextRefreshAt == at("2026-09-07 09:40").addingTimeInterval(1))
    }

    /// 不存在的日期（2月30日、13月、0日）要丢弃，不能被日历“滚”成别的日子
    @Test func impossibleDatesAreDropped() {
        #expect(TermCalendar.parseDay("2026-02-30", calendar: shanghai) == nil)
        #expect(TermCalendar.parseDay("2026-13-01", calendar: shanghai) == nil)
        #expect(TermCalendar.parseDay("2026-10-00", calendar: shanghai) == nil)
        #expect(TermCalendar.parseDay("2028-02-29", calendar: shanghai) != nil)    // 闰日是有效的
        #expect(TermCalendar.parseDay("2027-02-29", calendar: shanghai) == nil)
    }

    /// 一条坏的假期数据（结束日期不存在）不能影响别的日子
    @Test func badHolidayDoesNotBlockRealDays() {
        let monday = course("M", weekday: 1, 1, 2, weeks: [1, 2, 3, 4])
        let occ = ScheduleExpander.occurrences(of: Schedule(theoryList: [monday]), in: term)
        let campus = CampusCalendar(holidays: [HolidayRange(title: "坏数据", from: "2026-09-14", to: "2026-09-31")])
        let r = CalendarOverlay.apply(to: occ, calendar: campus, term: term)
        #expect(r.occurrences.count == 4)
        #expect(r.dayBlocks.isEmpty)
    }

    /// 同名同教师、教室 / 时间不同的两项重叠时，用户选的那一项要能被准确选中
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
