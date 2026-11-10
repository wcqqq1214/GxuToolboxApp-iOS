import Foundation
import Testing
@testable import ScheduleKit

struct FormattingTests {
    @Test func describesWeeks() {
        #expect(WeekFormatter.describe([1, 2, 3, 4]) == "1-4周")
        #expect(WeekFormatter.describe([1, 2, 3, 4, 6, 8, 9]) == "1-4、6、8-9周")
        #expect(WeekFormatter.describe([1, 3, 5, 7, 9, 11, 13, 15]) == "1-15周(单)")
        #expect(WeekFormatter.describe([2, 4, 6, 8]) == "2-8周(双)")
        #expect(WeekFormatter.describe([3, 5]) == "3、5周")
        #expect(WeekFormatter.describe([7]) == "7周")
        #expect(WeekFormatter.describe([]) == "")
    }

    @Test func formatsLocations() {
        // 只显示教室，不拼楼名；教室为空才显示楼名
        #expect(LocationFormatter.display(building: "西三教", venue: "西3-406") == "西3-406")
        #expect(LocationFormatter.display(building: "第六教学楼A区", venue: "6A-307") == "6A-307")
        #expect(LocationFormatter.display(building: "西二教", venue: " 西2-202 ") == "西2-202")
        #expect(LocationFormatter.display(building: "西三教", venue: "") == "西三教")
        #expect(LocationFormatter.display(building: "", venue: "") == "")
        // 导航 / 地图匹配用的完整文案仍然带楼名
        #expect(LocationFormatter.fullText(building: "西三教", venue: "西3-406") == "西三教西3-406")
        #expect(LocationFormatter.display(building: "体育学院", venue: "西体育馆") == "西体育馆")
        #expect(LocationFormatter.display(building: "", venue: "体育学院西体育馆") == "西体育馆")
        #expect(LocationFormatter.display(building: "体育学院", venue: "北篮球场") == "北篮球场")
        #expect(LocationFormatter.display(building: "体育学院", venue: "操场") == "体育学院操场")   // 无方位字时原样
        #expect(LocationFormatter.blockText(venue: "西3-406", singleLine: false) == "西3\n406")
        #expect(LocationFormatter.blockText(venue: "西3-406", singleLine: true) == "西3-406")
    }

    @Test func mapsTimeToGridPosition() {
        func pos(_ t: String) -> Double { ClassPeriods.position(at: at("2026-09-07 " + t), calendar: shanghai) }
        #expect(pos("06:00") == 0)
        #expect(pos("08:00") == 0)
        #expect(abs(pos("08:22") - 0.5) < 0.05)
        #expect(pos("08:50") == 1)           // 课间停在第 1 节下沿
        #expect(pos("08:55") == 1)
        #expect(pos("12:30") == 4)           // 午休停在第 4 节下沿
        #expect(pos("14:30") == 4)
        #expect(pos("18:50") > 9 && pos("18:50") < 10)   // 重叠时以第 10 节为准
        #expect(pos("23:30") == 13)
    }

    @Test func weekdayNames() {
        #expect(WeekdayName.short(1) == "一" && WeekdayName.short(7) == "日")
        #expect(WeekdayName.full(3) == "周三")
    }
}
