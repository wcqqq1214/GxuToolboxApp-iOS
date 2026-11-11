import Foundation
import ScheduleKit
import Testing
@testable import FeatureCourse

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return c
}()

private func day(_ s: String) -> Date { DayText.parse(s, calendar: cal)! }

private let campus = CampusCalendar(
    timeShift: [ShiftRule(workDate: "2026-01-04", restDate: "2026-01-02"), ShiftRule(workDate: "2026-09-20", restDate: "2026-10-06"), ShiftRule(workDate: "2026-10-10", restDate: "2026-10-07")],
    holidays: [
        HolidayRange(title: "国庆节", from: "2026-10-01", to: "2026-10-07"),
        HolidayRange(title: "元旦", from: "2026-01-01", to: "2026-01-03"),
        HolidayRange(title: "运动会", from: "2026-11-06", to: "2026-11-08", kind: .school),
        HolidayRange(title: "坏数据", from: "x", to: "y"),
        HolidayRange(title: "倒置", from: "2026-05-05", to: "2026-05-01"),
    ]
)

@Suite struct HolidayLogicTests {
    @Test func statusSplitAndOrder() {
        let p = HolidayPresentation.build(campus, now: day("2026-11-05"), calendar: cal)
        #expect(p.current.map(\.holiday.title) == ["运动会"])
        #expect(p.current.first?.status == .upcoming)
        #expect(p.current.first?.daysUntil == 1)
        #expect(p.past.map(\.holiday.title) == ["国庆节", "元旦"])
    }

    @Test func ongoingAndDays() {
        let p = HolidayPresentation.build(campus, now: day("2026-11-07"), calendar: cal)
        #expect(p.current.first?.status == .ongoing)
        #expect(p.current.first?.days == 3)
        #expect(p.current.first?.daysUntil == nil)
        let lastDay = HolidayPresentation.build(campus, now: day("2026-11-08"), calendar: cal)
        #expect(lastDay.current.first?.status == .ongoing)
        let after = HolidayPresentation.build(campus, now: day("2026-11-09"), calendar: cal)
        #expect(after.current.isEmpty)
    }

    @Test func makeupDaysAttachToHolidayContainingRestDate() {
        let p = HolidayPresentation.build(campus, now: day("2026-11-05"), calendar: cal)
        let national = p.past.first { $0.holiday.title == "国庆节" }
        #expect(national?.makeupDays == [day("2026-09-20"), day("2026-10-10")])
        #expect(national?.days == 7)
        #expect(p.past.first { $0.holiday.title == "元旦" }?.makeupDays == [day("2026-01-04")])
    }

    @Test func emptyCalendar() {
        let p = HolidayPresentation.build(.empty, now: .now, calendar: cal)
        #expect(p.current.isEmpty && p.past.isEmpty)
    }

    @Test func dayFormatting() {
        #expect(DayText.monthDay(day("2026-02-05"), calendar: cal) == "2月5日")
        #expect(DayText.monthDayWeekday(day("2026-01-04"), calendar: cal) == "1月4日（周日）")
        #expect(DayText.monthDayWeekday(day("2026-10-10"), calendar: cal) == "10月10日（周六）")
        #expect(DayText.parse("abc", calendar: cal) == nil)
    }

    @Test func timeShiftSplit() {
        let p = TimeShiftPresentation.build(campus, now: day("2026-09-01"), calendar: cal)
        #expect(p.current.map(\.workDay) == [day("2026-09-20"), day("2026-10-10")])
        #expect(p.past.map(\.workDay) == [day("2026-01-04")])
        let none = TimeShiftPresentation.build(.empty, now: .now, calendar: cal)
        #expect(none.current.isEmpty && none.past.isEmpty)
    }
}
