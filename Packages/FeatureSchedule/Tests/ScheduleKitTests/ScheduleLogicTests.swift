import Foundation
import Testing
@testable import ScheduleKit

struct ScheduleLogicTests {
    @Test func decodesRealResponse() throws {
        let schedule = try personalFixture()
        #expect(schedule.theoryList.count == 26)
        #expect(schedule.practiceList.count == 4)
        #expect(schedule.theoryList.allSatisfy { $0.isValid })
        #expect(Set(schedule.theoryList.map(\.courseName)).count == 9)
        // weeks 在真实响应里就是 [Int]；同一门课的周次可以不连续（国庆周被跳过）
        let mechanics = try #require(schedule.theoryList.first { $0.courseName == "材料力学" })
        #expect(mechanics.weeks == [1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17])
        #expect(mechanics.building == "东六教" && mechanics.venueName == "6A-408" && mechanics.weekday == 1)
        // 真实数据里同名同节次的课程不会撞 id，同一门课分周换教室也是不同条目
        #expect(Set(schedule.theoryList.map(\.id)).count == schedule.theoryList.count)
        let software = schedule.theoryList.filter { $0.courseName == "地下结构设计软件" }
        #expect(software.count == 2 && Set(software.map(\.venueName)).count == 2)
    }

    @Test func practiceTitleStripsEmbeddedTeacherAndWeeks() throws {
        let practice = try personalFixture().practiceList
        #expect(practice.map(\.title) == ["创新创业实践", "生产实习（岩土）", "地下工程施工课程设计", "地下建筑结构课程设计"])
        #expect(practice[0].courseName.contains("●教师") && practice[0].time == "1-16周")
        #expect(PracticeCourse(courseName: "无标记").title == "无标记")
        #expect(PracticeCourse(courseName: "●只有标记").title == "●只有标记")
    }

    /// 防御：真实响应现在全是规整类型，但适配器对缺失字段会给默认值、数字可能是字符串
    @Test func decodesDefensively() throws {
        let json = #"{"theoryList":[{"courseName":"A","sectionRange":"3-4","weeks":[1],"weekday":"2","xkrs":"NaN","enrollmentCount":"NaN","seatCount":""}]}"#
        let lenient = try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))
        let a = lenient.theoryList[0]
        #expect(a.begin == 3 && a.end == 4 && a.weekday == 2 && a.enrollmentCount == 0 && a.seatCount == 0)
        #expect(try JSONDecoder().decode(Schedule.self, from: Data("{}".utf8)).theoryList.isEmpty)
        let dirty = #"{"theoryList":[{"courseName":"脏数据","weeks":[1],"weekday":0}]}"#
        #expect(try JSONDecoder().decode(Schedule.self, from: Data(dirty.utf8)).theoryList[0].isValid == false)
    }

    @Test func outOfRangeNumbersFallBackToSectionRange() throws {
        let json = #"{"theoryList":[{"sectionRange":"3-4","begin":1e20,"end":-1e20,"weekday":2.5,"weeks":[1]}]}"#
        let schedule = try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))
        let course = try #require(schedule.theoryList.first)
        #expect(course.begin == 3)
        #expect(course.end == 4)
        #expect(course.weekday == 2)
    }

    @Test func expandsRealScheduleIntoDatedOccurrences() throws {
        let all = ScheduleExpander.occurrences(of: try personalFixture(), in: realTerm)
        #expect(all.count == 157)   // 各课程 weeks 数量之和
        #expect(all == all.sorted { $0.startsAt < $1.startsAt })
        // 材料力学周一 1-2 节：第 6 周在 10 月 13 日，第 5 周（国庆周）被跳过
        let week6 = try #require(all.first { $0.course.courseName == "材料力学" && $0.weekday == 1 && $0.week == 6 })
        #expect(week6.startsAt == at("2025-10-13 08:00") && week6.endsAt == at("2025-10-13 09:40"))
        #expect(!all.contains { $0.course.courseName == "材料力学" && $0.weekday == 1 && $0.week == 5 })
        // 晚课 11-12 节：19:40–21:15
        let evening = try #require(all.first { $0.course.sectionRange == "11-12" })
        #expect(shanghai.component(.hour, from: evening.startsAt) == 19 && shanghai.component(.minute, from: evening.startsAt) == 40)
        #expect(shanghai.component(.hour, from: evening.endsAt) == 21 && shanghai.component(.minute, from: evening.endsAt) == 15)
        // 星期与日期对得上
        #expect(all.allSatisfy { realTerm.weekday(of: $0.date) == $0.weekday })
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
        // key 是组内课程完整 id（含教室、时间）排序后的结果：稳定、与顺序无关、同名课也不会混
        let key = ScheduleExpander.conflictKey(groups[0])
        #expect(key == groups[0].items.map { $0.course.id }.sorted())
        #expect(Set(key).count == 3)
    }

    @Test func realScheduleHasConflictsThatStack() throws {
        let index = ScheduleIndex(occurrences: ScheduleExpander.occurrences(of: try personalFixture(), in: realTerm))
        #expect(index.maxWeek == 17)
        #expect(index.items(inWeek: 1).count == 11)
        #expect(index.items(inWeek: 18).isEmpty)
        // 第 1 周周一：材料力学和混凝土结构基本原理同在 1-2 节，土力学在 5-6 节
        let monday = ScheduleExpander.conflictGroups(index.items(inWeek: 1, weekday: 1))
        #expect(monday.map { $0.items.map(\.course.courseName).sorted() }
            == [["材料力学", "混凝土结构基本原理"], ["土力学"]])
        #expect(monday[0].isConflict && monday[0].begin == 1 && monday[0].end == 2)
        // 整学期共 29 个冲突组
        let conflicts = (1...20).flatMap { week in
            (1...7).flatMap { ScheduleExpander.conflictGroups(index.items(inWeek: week, weekday: $0)) }
        }.filter(\.isConflict)
        #expect(conflicts.count == 29)
    }
}
