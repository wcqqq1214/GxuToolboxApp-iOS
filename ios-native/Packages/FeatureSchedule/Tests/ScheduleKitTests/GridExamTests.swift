import Foundation
import Testing
@testable import ScheduleKit

struct GridExamTests {
    private func exam(_ id: String, _ start: String, _ end: String) -> GridExam {
        GridExam(id: id, title: id, start: at(start), end: at(end))
    }

    @Test func periodsFollowRNRule() throws {
        // 09:00–11:00：第一个“下课晚于 09:00”的是第 2 节（08:55–09:40）；最后一个“上课早于 11:00”的是第 4 节（10:55 开始）
        let a = try #require(ExamPlacement.periods(start: at("2026-09-07 09:00"), end: at("2026-09-07 11:00"), calendar: shanghai))
        #expect(a.begin == 2 && a.end == 4)
        // 恰好 08:00–09:40：第 1 节到第 2 节（第 3 节 10:00 开始，不早于 09:40）
        let b = try #require(ExamPlacement.periods(start: at("2026-09-07 08:00"), end: at("2026-09-07 09:40"), calendar: shanghai))
        #expect(b.begin == 1 && b.end == 2)
        // 下午
        let c = try #require(ExamPlacement.periods(start: at("2026-09-07 14:30"), end: at("2026-09-07 16:30"), calendar: shanghai))
        #expect(c.begin == 5 && c.end == 7)
        // 晚于最后一节下课：没有节次
        #expect(ExamPlacement.periods(start: at("2026-09-07 22:30"), end: at("2026-09-07 23:30"), calendar: shanghai) == nil)
    }

    @Test func blocksLandOnTheirDateAndDropOutOfTermOnes() {
        // term 从 2026-09-07 开学，共 18 周；考试不受调课影响，落在日历日期上
        let inTerm = exam("期中", "2026-09-16 09:00", "2026-09-16 11:00")          // 第 2 周周三
        let before = exam("早了", "2026-09-01 09:00", "2026-09-01 11:00")
        let after = exam("晚了", "2027-03-01 09:00", "2027-03-01 11:00")
        let blocks = ExamPlacement.blocks(for: [after, inTerm, before], term: term)
        #expect(blocks.map(\.id) == ["期中"])
        #expect(blocks[0].week == 2 && blocks[0].weekday == 3 && blocks[0].begin == 2 && blocks[0].end == 4)
    }

    @Test func indexExposesExamsByWeekAndDay() {
        let blocks = ExamPlacement.blocks(for: [exam("A", "2026-09-16 09:00", "2026-09-16 11:00")], term: term)
        let index = ScheduleIndex(occurrences: [], examBlocks: blocks)
        #expect(index.examBlocks(inWeek: 2, weekday: 3).count == 1)
        #expect(index.examBlocks(inWeek: 2, weekday: 4).isEmpty)
        #expect(index.examBlocks(inWeek: 3, weekday: 3).isEmpty)
    }
}
