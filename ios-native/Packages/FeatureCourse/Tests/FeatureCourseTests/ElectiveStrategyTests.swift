import Foundation
import Testing
@testable import FeatureCourse

private func course(_ name: String, _ credit: Double, system: String = "", belongTo: String = "", teacher: String = "教师") -> SelectedCourse {
    SelectedCourse(classId: UUID().uuidString, courseName: name, belongTo: belongTo, system: system, teacher: teacher, credit: credit, year: 2025, term: 1)
}

/// 每个年级的满足条件集合
private func completeSet(for grade: Int) -> [SelectedCourse] {
    switch grade {
    case 2021:
        // 总 8、线下 4（占比正好 50%）、领军、创业、艺术、东盟 + 民族、三门必修
        return [
            course("创业基础", 1, system: "创业"), course("中文写作实训", 1, system: "领军"), course("逻辑与批判性思维训练", 1, system: "艺术"),
            course("东盟A", 1, system: "东盟", belongTo: "网络课程"), course("民族A", 1, system: "民族", teacher: "网络教师"),
            course("网课1", 1, system: "其他", belongTo: "网络课程"), course("网课2", 1, system: "其他", belongTo: "网络课程"),
            course("线下补", 1, system: "其他"),
        ]
    case 2022, 2023, 2024:
        var list = [
            course("创业基础", 2, system: "创业"), course("中文写作实训", 1, system: "领军"), course("逻辑与批判性思维训练", 2, system: "艺术"),
            course("东盟A", 1, system: "东盟"), course("民族A", 1, system: "民族"), course("线下补", 3, system: "其他"),
        ]
        if grade >= 2023 { list.append(course("中华民族共同体概论", 0, system: "其他")) }
        return list
    default:   // 2025, 2026
        return [
            course("创新创业基础", 2, system: "创业"), course("艺", 2, system: "艺术与审美"), course("科", 1, system: "科技与伦理"),
            course("民", 1, system: "少数民族与中华文明（民族）"), course("海", 1, system: "亚热带与海洋生态（海洋）"), course("东", 1, system: "东盟历史与世界文化（东盟）"),
        ]
    }
}

@Suite struct ElectiveStrategyTests {
    @Test(arguments: [2021, 2022, 2023, 2024, 2025, 2026])
    func qualifiedWhenEverythingMet(grade: Int) {
        let strategy = ElectiveStrategies.strategy(forGrade: grade)
        let stats = strategy.calculate(completeSet(for: grade))
        #expect(stats.isQualified, "grade \(grade): \(stats.passed)")
        #expect(stats.remainingRequired.isEmpty)
        #expect(strategy.rows(stats).allSatisfy { $0.passed }, "grade \(grade)")
    }

    @Test(arguments: [2021, 2022, 2023, 2024, 2025, 2026])
    func emptyListFailsEverywhere(grade: Int) {
        let strategy = ElectiveStrategies.strategy(forGrade: grade)
        let stats = strategy.calculate([])
        #expect(!stats.isQualified)
        #expect(stats.totalScore == 0)
        #expect(stats.remainingRequired == strategy.requiredCourses)
        #expect(strategy.rows(stats).allSatisfy { !$0.passed })
    }

    @Test func requiredCoursesPerGrade() {
        #expect(ElectiveStrategies.strategy(forGrade: 2021).requiredCourses == ["创业基础", "中文写作实训", "逻辑与批判性思维训练"])
        #expect(ElectiveStrategies.strategy(forGrade: 2022).requiredCourses.count == 3)
        #expect(ElectiveStrategies.strategy(forGrade: 2023).requiredCourses.contains("中华民族共同体概论"))
        #expect(ElectiveStrategies.strategy(forGrade: 2024).requiredCourses.count == 4)
        #expect(ElectiveStrategies.strategy(forGrade: 2025).requiredCourses == ["创新创业基础"])
        #expect(ElectiveStrategies.strategy(forGrade: 2026).requiredCourses == ["创新创业基础"])
    }

    @Test func totalsAndOfflinePerGrade() {
        #expect(ElectiveStrategies.strategy(forGrade: 2021).totalRequired == 8)
        #expect(ElectiveStrategies.strategy(forGrade: 2021).offlineRequired == 4)
        for g in [2022, 2023, 2024] {
            #expect(ElectiveStrategies.strategy(forGrade: g).totalRequired == 10)
            #expect(ElectiveStrategies.strategy(forGrade: g).offlineRequired == 5)
        }
        for g in [2025, 2026] {
            #expect(ElectiveStrategies.strategy(forGrade: g).totalRequired == 8)
            #expect(ElectiveStrategies.strategy(forGrade: g).offlineRequired == 4)
        }
    }

    @Test func unknownGradeFallsBackTo2025() {
        #expect(ElectiveStrategies.strategy(forGrade: 2019).grade == 2025)
        #expect(ElectiveStrategies.strategy(forGrade: 2030).grade == 2025)
    }

    // 2021：线下占比 > 50% 不达标；艺术只要求修过（界面不显示这一项，但参与判断）
    @Test func y2021OfflineRatioAndHiddenArt() {
        let s = ElectiveStrategies.strategy(forGrade: 2021)
        var list = completeSet(for: 2021)
        // 再加 2 个线下学分：总 10、线下 6，占比 0.6 > 0.5
        list.append(course("线下", 2, system: "其他"))
        let stats = s.calculate(list)
        #expect(stats.offlineScore == 6)
        #expect(stats.passed["offlineScore"] == false)
        #expect(!stats.isQualified)
        // 去掉艺术：其他都达标，仍然不合格，但界面没有艺术这一行
        let noArt = s.calculate(completeSet(for: 2021).map { c in var c = c; if c.system == "艺术" { c.system = "其他" }; return c })
        #expect(noArt.passed["artScore"] == false)
        #expect(!noArt.isQualified)
        #expect(s.rows(noArt).map(\.id) == ["totalScore", "offlineScore", "lead", "ent", "special"])
    }

    // 2022–2024：艺术要求 2 学分；线下不看占比
    @Test(arguments: [2022, 2023, 2024])
    func creditEraArtNeedsTwoCredits(grade: Int) {
        let s = ElectiveStrategies.strategy(forGrade: grade)
        var list = completeSet(for: grade)
        list = list.map { c in var c = c; if c.system == "艺术" { c.credit = 1 }; return c }
        let stats = s.calculate(list)
        #expect(stats.art.score == 1)
        #expect(stats.passed["artScore"] == false)
        #expect(!stats.isQualified)
        #expect(s.rows(stats).first { $0.id == "art" }?.value == "1 / 2")
    }

    @Test(arguments: [2022, 2023, 2024])
    func creditEraSpecialModulesNeedTwoOfThree(grade: Int) {
        let s = ElectiveStrategies.strategy(forGrade: grade)
        let list = completeSet(for: grade).filter { $0.system != "民族" }   // 只剩东盟一个
        let stats = s.calculate(list)
        #expect(stats.specialModulesCount == 1)
        #expect(stats.passed["specialModules"] == false)
        #expect(s.rows(stats).first { $0.id == "special" }?.value == "1 / 2")
    }

    @Test func creditEraRequiresTotal10Not8() {
        let s = ElectiveStrategies.strategy(forGrade: 2022)
        // 满足所有项但总学分只有 9
        var list = completeSet(for: 2022)
        list[5].credit = 2   // 线下补 3 → 2：总 9
        let stats = s.calculate(list)
        #expect(stats.totalScore == 9)
        #expect(stats.passed["totalScore"] == false)
    }

    @Test func year2023And2024NeedFourthRequiredCourse() {
        for g in [2023, 2024] {
            let s = ElectiveStrategies.strategy(forGrade: g)
            let stats = s.calculate(completeSet(for: g).filter { $0.courseName != "中华民族共同体概论" })
            #expect(stats.remainingRequired == ["中华民族共同体概论"])
            #expect(!stats.isQualified)
        }
        // 2022 不要求
        #expect(ElectiveStrategies.strategy(forGrade: 2022).calculate(completeSet(for: 2022)).remainingRequired.isEmpty)
    }

    // 2025/2026：每个模块各要求学分；创业学分只在界面展示，不影响毕业资格（RN 口径）
    @Test(arguments: [2025, 2026])
    func modernModulesAndEntrepreneurshipQuirk(grade: Int) {
        let s = ElectiveStrategies.strategy(forGrade: grade)
        var list = completeSet(for: grade)
        list = list.map { c in var c = c; if c.system == "创业" { c.credit = 1 }; return c }   // 创业只有 1，要求 2
        let stats = s.calculate(list)
        #expect(stats.entrepreneurship.score == 1)
        #expect(s.rows(stats).first { $0.id == "ent" }?.passed == false)
        #expect(stats.passed["entModule"] == nil)
        // 总学分 7 < 8 → 不合格；补回 1 学分的其他课后合格，此时创业行仍显示未达标
        #expect(!stats.isQualified)
        let patched = s.calculate(list + [course("其他", 1, system: "其他")])
        #expect(patched.isQualified)
        #expect(s.rows(patched).first { $0.id == "ent" }?.passed == false)

        let missingOcean = s.calculate(completeSet(for: grade).filter { $0.system.contains("海洋") == false })
        #expect(missingOcean.passed["ocean"] == false)
        #expect(!missingOcean.isQualified)
        #expect(s.rows(stats).map(\.id) == ["totalScore", "offlineScore", "ent", "art", "tech", "ethnic", "ocean", "asean"])
    }

    @Test func modernRequiredCourseName() {
        let s = ElectiveStrategies.strategy(forGrade: 2025)
        let stats = s.calculate(completeSet(for: 2025).filter { $0.courseName != "创新创业基础" })
        #expect(stats.remainingRequired == ["创新创业基础"])
        #expect(!stats.isQualified)
    }

    @Test func onlineDetectionAndSharedModules() {
        let s = ElectiveStrategies.strategy(forGrade: 2025)
        // 一门课同时属于两个模块；网络教师和"网络"归属都算线上
        let stats = s.calculate([
            course("跨模块", 2, system: "艺术与审美+创业"),
            course("网课", 1, system: "其他", belongTo: "网络通识"),
            course("网课2", 1, system: "其他", teacher: "网络教师"),
        ])
        #expect(stats.art.score == 2 && stats.entrepreneurship.score == 2)
        #expect(stats.totalScore == 4)
        #expect(stats.offlineScore == 2)
    }

    @Test func numberFormatting() {
        #expect(ElectiveStrategy.number(8) == "8")
        #expect(ElectiveStrategy.number(3.5) == "3.5")
    }

    @Test func nameFormat() {
        #expect(ElectiveStrategies.strategy(forGrade: 2024).name == "2024 级校选课毕业要求")
    }
}
