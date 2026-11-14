import Foundation
import ScheduleKit
import Testing
@testable import ScheduleUI

struct RescheduleArrangementTests {
    @Test func beforeAndAfterKeepTheirOwnWeeksAndLocationsWithoutAReason() throws {
        let record = try JSONDecoder().decode(CourseReschedule.self, from: Data(#"{"before":{"weeks":"2,4,6","weekday":"一","sections":"1-2","teacher":"教师甲","venueName":"西一-101"},"after":{"weeks":"3,5,7","weekday":"星期二","sections":"3-4","teacher":"教师乙","venueName":"西二-202"}}"#.utf8))
        let before = RescheduleArrangementSummary(record.before)
        let after = RescheduleArrangementSummary(record.after)
        #expect(before.weeks == "2,4,6")
        #expect(after.weeks == "3,5,7")
        #expect(before.weekday == "一")
        #expect(after.weekday == "星期二")
        #expect(before.sections == "1-2")
        #expect(after.sections == "3-4")
        #expect(before.venue == "西一-101")
        #expect(after.venue == "西二-202")
        #expect(before.teacher == "教师甲")
        #expect(after.teacher == "教师乙")
    }

    @Test func missingValuesAreExplicitAndNeverInheritTheOtherArrangement() throws {
        let record = try JSONDecoder().decode(CourseReschedule.self, from: Data(#"{"before":{"weeks":"2","venueName":"西一-101"},"after":{"weeks":" \n ","weekday":null,"venueName":"\t"}}"#.utf8))
        let after = RescheduleArrangementSummary(record.after)
        #expect(after.weeks == "未提供")
        #expect(after.weekday == "未提供")
        #expect(after.sections == "未提供")
        #expect(after.venue == "未提供")
        #expect(after.teacher == "未提供")
    }

    @Test func unfamiliarSourceTextRemainsReadable() throws {
        let record = try JSONDecoder().decode(CourseReschedule.self, from: Data(#"{"before":{},"after":{"weeks":" 1-9周（单） ","weekday":"待定","sections":"另行通知","venueName":" 校外实习基地\n第二教学楼 ","teacher":" 教师甲、教师乙 "}}"#.utf8))
        let after = RescheduleArrangementSummary(record.after)
        #expect(after.weeks == "1-9周（单）")
        #expect(after.weekday == "待定")
        #expect(after.sections == "另行通知")
        #expect(after.venue == "校外实习基地\n第二教学楼")
        #expect(after.teacher == "教师甲、教师乙")
    }
}
