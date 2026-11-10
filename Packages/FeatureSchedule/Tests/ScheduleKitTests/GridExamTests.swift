import Foundation
import GxuFoundation
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

struct RelatedExamsTests {
    private let t1 = AcademicTerm(year: 2026, term: 1)
    private let t0 = AcademicTerm(year: 2025, term: 2)

    private func exam(_ title: String, _ start: String, _ end: String, term: AcademicTerm? = AcademicTerm(year: 2026, term: 1)) -> GridExam {
        GridExam(id: title + start, title: title, start: at(start), end: at(end), term: term)
    }

    @Test func matchesByNameSortedByStart() {
        let exams = [exam("高等数学", "2026-12-20 09:00", "2026-12-20 11:00"), exam("大学英语", "2026-12-18 09:00", "2026-12-18 11:00"), exam("高等数学", "2026-11-10 09:00", "2026-11-10 11:00")]
        #expect(RelatedExams.matching(courseName: " 高等数学", in: exams, term: t1).map(\.start) == [at("2026-11-10 09:00"), at("2026-12-20 09:00")])
        #expect(RelatedExams.matching(courseName: "", in: exams, term: t1).isEmpty)
    }

    @Test func badgeStates() {
        let e = exam("高等数学", "2026-11-08 09:00", "2026-11-08 11:00")
        #expect(RelatedExams.badge(for: e, now: at("2026-11-06 10:00"), calendar: shanghai) == "2 天后")
        #expect(RelatedExams.badge(for: e, now: at("2026-11-08 07:00"), calendar: shanghai) == "今天考试")
        #expect(RelatedExams.badge(for: e, now: at("2026-11-08 12:00"), calendar: shanghai) == "已结束")
    }
}

extension RelatedExamsTests {
    @Test func sameNamedCourseOnlyShowsTheViewedTerm() {
        // 重修：往届（2025 学年第 2 学期）和当前学期各有一场“高等数学”，不能把旧考试列出来
        let exams = [
            exam("高等数学", "2026-06-20 09:00", "2026-06-20 11:00", term: t0),
            exam("高等数学", "2026-12-20 09:00", "2026-12-20 11:00"),
        ]
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: t1).map(\.start) == [at("2026-12-20 09:00")])
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: t0).map(\.start) == [at("2026-06-20 09:00")])
    }

    @Test func termWithoutRelatedExamsIsEmpty() {
        let exams = [exam("高等数学", "2026-06-20 09:00", "2026-06-20 11:00", term: t0)]
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: t1).isEmpty)   // 界面据此隐藏这一组
    }

    @Test func examsWithoutSourceTermAreNotGuessedByDate() {
        // 日期落在当前学期里，但没有来源学期信息：不匹配
        let exams = [exam("高等数学", "2026-12-20 09:00", "2026-12-20 11:00", term: nil)]
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: t1).isEmpty)
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: nil).isEmpty)
    }
}
