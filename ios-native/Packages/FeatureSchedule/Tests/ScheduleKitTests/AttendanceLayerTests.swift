import Foundation
import Testing
@testable import ScheduleKit

struct AttendanceLayerTests {
    // term：2026-09-07（周一）开学；9-21 周一，第 3 周
    private let monday = course("大学英语", weekday: 1, 3, 4, weeks: Array(1...18))

    private func occurrence() throws -> CourseOccurrence {
        let all = ScheduleExpander.occurrences(of: Schedule(theoryList: [monday]), in: term)
        return try #require(all.first { $0.date == at("2026-09-21") })
    }

    @Test func matchesByDateAndPeriodRange() throws {
        let index = AttendanceIndex([AttendanceMark(date: "2026-09-21", periodRange: "3,4", statusCode: 2)], calendar: shanghai)
        #expect(index.status(for: try occurrence()) == .late)
    }

    @Test func acceptsUnpaddedDatesAndOtherStatuses() throws {
        let index = AttendanceIndex([AttendanceMark(date: "2026-9-21", periodRange: "3, 4", statusCode: 4)], calendar: shanghai)
        #expect(index.status(for: try occurrence()) == .absent)
        for (code, status) in [(1, AttendanceStatus.normal), (5, .notStarted), (100, .noNeed)] {
            let i = AttendanceIndex([AttendanceMark(date: "2026-09-21", periodRange: "3,4", statusCode: code)], calendar: shanghai)
            #expect(i.status(for: try occurrence()) == status)
        }
    }

    @Test func otherPeriodsOrDaysDoNotMatch() throws {
        let marks = [
            AttendanceMark(date: "2026-09-21", periodRange: "1,2", statusCode: 1),
            AttendanceMark(date: "2026-09-22", periodRange: "3,4", statusCode: 1),
        ]
        #expect(AttendanceIndex(marks, calendar: shanghai).status(for: try occurrence()) == nil)
    }

    @Test func invalidRecordsAreIgnored() throws {
        let bad = [
            AttendanceMark(date: "2026-02-30", periodRange: "3,4", statusCode: 1),     // 无效日期不顺延
            AttendanceMark(date: "2026-09-21", periodRange: "", statusCode: 1),
            AttendanceMark(date: "2026-09-21", periodRange: "3,x", statusCode: 1),
            AttendanceMark(date: "2026-09-21", periodRange: "4,3", statusCode: 1),     // 止早于起
            AttendanceMark(date: "2026-09-21", periodRange: "0,4", statusCode: 1),     // 超出 1–13
            AttendanceMark(date: "2026-09-21", periodRange: "3,14", statusCode: 1),
            AttendanceMark(date: "2026-09-21", periodRange: "3,4", statusCode: 7),     // 未知状态码
            AttendanceMark(date: "2026-09-21", periodRange: "3,4", statusCode: nil),
        ]
        #expect(AttendanceIndex(bad, calendar: shanghai).isEmpty)
    }

    @Test func customActivitiesNeverGetAttendance() throws {
        var activity = monday
        activity.customID = "act-1"
        let all = ScheduleExpander.occurrences(of: Schedule(theoryList: [activity]), in: term)
        let index = AttendanceIndex([AttendanceMark(date: "2026-09-21", periodRange: "3,4", statusCode: 1)], calendar: shanghai)
        let first = try #require(all.first { $0.date == at("2026-09-21") })
        #expect(index.status(for: first) == nil)
    }
}
