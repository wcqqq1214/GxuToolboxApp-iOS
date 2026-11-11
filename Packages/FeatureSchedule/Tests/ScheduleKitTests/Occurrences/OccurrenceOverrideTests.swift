import Foundation
import Testing
@testable import ScheduleKit

struct OccurrenceOverrideTests {
    private func occurrences() -> [CourseOccurrence] {
        let lab = course("大学物理实验", weekday: 3, 5, 8, weeks: [1, 2, 3], teacher: "原教师", venue: "原教室")
        let math = course("高等数学", weekday: 3, 1, 2, weeks: [1, 2, 3], teacher: "数学老师", venue: "西3-406")
        return ScheduleExpander.occurrences(of: Schedule(theoryList: [lab, math]), in: term)
    }

    @Test func overridesOnlyMatchingNameAndDate() {
        let result = OccurrenceOverrides.apply(
            [OccurrenceOverride(date: at("2026-09-16"), courseNameContains: "物理实验", teacher: "实验教师", venue: "理科楼101")],
            to: occurrences()
        )
        let lab2 = result.first { $0.course.courseName == "大学物理实验" && $0.week == 2 }
        #expect(lab2?.course.teacher == "实验教师" && lab2?.course.venueName == "理科楼101")
        #expect(lab2?.course.courseName == "大学物理实验")
        #expect(result.first { $0.course.courseName == "大学物理实验" && $0.week == 1 }?.course.teacher == "原教师")
        #expect(result.first { $0.course.courseName == "高等数学" && $0.week == 2 }?.course.teacher == "数学老师")
    }

    @Test func emptyValuesKeepOriginals() {
        let result = OccurrenceOverrides.apply(
            [OccurrenceOverride(date: at("2026-09-16"), courseNameContains: "物理实验", teacher: "", venue: "理科楼101")],
            to: occurrences()
        )
        let lab2 = result.first { $0.course.courseName == "大学物理实验" && $0.week == 2 }
        #expect(lab2?.course.teacher == "原教师" && lab2?.course.venueName == "理科楼101")
    }

    @Test func noOverridesReturnsInputUntouched() {
        let input = occurrences()
        #expect(OccurrenceOverrides.apply([], to: input) == input)
    }
}
