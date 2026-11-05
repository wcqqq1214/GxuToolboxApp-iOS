import Foundation
import Testing
@testable import ScheduleKit

struct ScheduleLogicTests {
    @Test func decodesFixtureLeniently() throws {
        let schedule = try personalFixture()
        #expect(schedule.theoryList.count == 5)
        #expect(schedule.practiceList.first?.courseName == "计算机网络原理实践")
        let sports = try #require(schedule.theoryList.first { $0.courseName == "体育" })
        #expect(sports.weekday == 7)            // "7" 字符串
        #expect(sports.enrollmentCount == 0)    // "NaN" → 0
        #expect(sports.seatCount == 0)
        #expect(schedule.theoryList.filter(\.isValid).count == 4)   // 脏数据被判为无效
        // 缺字段：begin / end 从 sectionRange 推出
        let json = #"{"theoryList":[{"courseName":"A","sectionRange":"3-4","weeks":[1],"weekday":"2"}]}"#
        let lenient = try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))
        #expect(lenient.theoryList[0].begin == 3 && lenient.theoryList[0].end == 4)
        #expect(try JSONDecoder().decode(Schedule.self, from: Data("{}".utf8)).theoryList.isEmpty)
    }

    @Test func expandsOccurrencesWithRealDates() throws {
        let schedule = try personalFixture()
        let all = ScheduleExpander.occurrences(of: schedule, in: term)
        // 高数 16 + 程序设计 8 + 物理实验 2 + 体育 2，脏数据丢弃
        #expect(all.count == 28)
        #expect(all == all.sorted { $0.startsAt < $1.startsAt })
        let math3 = try #require(all.first { $0.course.courseName == "高等数学" && $0.week == 3 })
        #expect(math3.startsAt == at("2026-09-21 08:00"))
        #expect(math3.endsAt == at("2026-09-21 09:40"))
        let pe2 = try #require(all.first { $0.course.courseName == "体育" && $0.week == 2 })
        #expect(pe2.date == at("2026-09-20"))   // 第 2 周周日
        #expect(pe2.startsAt == at("2026-09-20 18:10"))
        #expect(pe2.endsAt == at("2026-09-20 19:30"))
    }

    @Test func dropsOutOfRangeCourses() {
        let schedule = Schedule(theoryList: [
            course("越界节次", 12, 14), course("反向", 4, 3), course("周末外", weekday: 8, 1, 2),
            course("周次非法", 1, 2, weeks: [0, -1]), course("正常", 1, 2),
        ])
        let names = ScheduleExpander.occurrences(of: schedule, in: term).map(\.course.courseName)
        #expect(names == ["正常"])
    }

    @Test func conflictGroupsAreTransitive() throws {
        let schedule = Schedule(theoryList: [
            course("A", 1, 2), course("B", 2, 4), course("C", 4, 5), course("D", 7, 8), course("E", 6, 6),
        ])
        let day = ScheduleExpander.occurrences(of: schedule, in: term)
        let groups = ScheduleExpander.conflictGroups(day)
        #expect(groups.map { $0.items.map(\.course.courseName) } == [["A", "B", "C"], ["E"], ["D"]])
        #expect(groups.map(\.isConflict) == [true, false, false])
        #expect(groups[0].begin == 1 && groups[0].end == 5)
        #expect(ScheduleExpander.conflictKey(groups[0]) == ["A_", "B_", "C_"])
    }

    @Test func indexFindsItemsByWeekAndDay() throws {
        let index = ScheduleIndex(occurrences: ScheduleExpander.occurrences(of: try personalFixture(), in: term))
        #expect(index.items(inWeek: 1, weekday: 1).count == 2)   // 高数 + 程序设计冲突
        #expect(index.items(inWeek: 2, weekday: 1).count == 1)
        #expect(index.items(inWeek: 17).isEmpty)
        #expect(index.maxWeek == 16)
    }
}
