import Foundation
import Testing
@testable import ScheduleKit

struct PeriodRowsTests {
    @Test func twelveRowsWithPeriodsNineAndTenMerged() {
        #expect(PeriodRows.count == 12)
        #expect(PeriodRows.all.map(\.label) == ["1", "2", "3", "4", "5", "6", "7", "8", "9-10", "11", "12", "13"])
        let merged = PeriodRows.all[8]
        #expect(merged.isMerged && merged.startText == "18:10" && merged.endText == "19:30")
        // 其他行同时有上课和下课时间
        #expect(PeriodRows.all[0].startText == "08:00" && PeriodRows.all[0].endText == "08:45")
        #expect(PeriodRows.all[11].startText == "21:20" && PeriodRows.all[11].endText == "22:05")
    }

    @Test func periodToRowMapping() {
        #expect((1...8).map(PeriodRows.row(ofPeriod:)) == Array(1...8))
        #expect(PeriodRows.row(ofPeriod: 9) == 9 && PeriodRows.row(ofPeriod: 10) == 9)
        #expect((11...13).map(PeriodRows.row(ofPeriod:)) == [10, 11, 12])
        // 只占第 9 或第 10 节的课都落在合并行里；跨合并行的课占用连续的行
        #expect(PeriodRows.rows(begin: 9, end: 9) == 9...9)
        #expect(PeriodRows.rows(begin: 10, end: 10) == 9...9)
        #expect(PeriodRows.rows(begin: 8, end: 9) == 8...9)
        #expect(PeriodRows.rows(begin: 10, end: 11) == 9...10)
        #expect(PeriodRows.rows(begin: 9, end: 10) == 9...9)
        #expect(PeriodRows.rows(begin: 1, end: 13) == 1...12)
    }

    @Test func classPeriodsDataIsUntouched() {
        #expect(ClassPeriods.count == 13)
        #expect(ClassPeriods.period(9)?.startText == "18:10" && ClassPeriods.period(9)?.endText == "18:55")
        #expect(ClassPeriods.period(10)?.startText == "18:45" && ClassPeriods.period(10)?.endText == "19:30")
    }

    @Test func positionIsLinearWithinMergedRow() {
        func at(_ h: Int, _ m: Int) -> Date {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
            return c.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: h, minute: m))!
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        #expect(PeriodRows.position(at: at(7, 0), calendar: calendar) == 0)
        #expect(PeriodRows.position(at: at(8, 0), calendar: calendar) == 0)
        #expect(PeriodRows.position(at: at(9, 50), calendar: calendar) == 2)             // 课间停在上一行下沿
        #expect(abs(PeriodRows.position(at: at(18, 50), calendar: calendar) - 8.5) < 0.001)   // 合并行中点 18:50
        #expect(abs(PeriodRows.position(at: at(19, 30), calendar: calendar) - 9) < 0.001)     // 合并行结束
        #expect(PeriodRows.position(at: at(23, 0), calendar: calendar) == 12)
    }
}
