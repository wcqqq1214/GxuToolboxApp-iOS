import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureCourse

// 样例按 RN v2.2 `schema/progress.ts` 构造（不是真实响应，学号、课程均为虚构），真实脱敏样本到手后再核对。
private func sample(studentId: String = "2024000001", complete: Bool = true, qualified: Bool? = true,
                    passed: Bool? = false) -> String {
    let passedJSON = passed.map(String.init) ?? "null"
    let qualifiedJSON = qualified.map(String.init) ?? "null"
    return """
    {"studentId":"\(studentId)","grade":2024,"ruleId":"r2024","ruleVersion":"1","ruleName":"2024级通识选修要求",
     "computedAt":"2026-11-05T08:30:00.000Z","complete":\(complete),
     "stats":{"totalCredits":4,"offlineCredits":2,"modules":{
       "lead":{"credits":0,"courseCount":0},"entrepreneurship":{"credits":0,"courseCount":0},
       "art":{"credits":2,"courseCount":1},"asean":{"credits":0,"courseCount":0},
       "ethnic":{"credits":0,"courseCount":0},"ocean":{"credits":2,"courseCount":1}}},
     "requirements":[
       {"key":"total","label":"通识选修总学分","actual":4,"required":6,"operator":"gte","unit":"credits","passed":\(passedJSON)},
       {"key":"online","label":"网课学分占比","actual":0.5,"required":0.4,"operator":"lte","unit":"ratio","passed":false},
       {"key":"modules","label":"覆盖模块","actual":2,"required":2,"operator":"gte","unit":"modules","passed":true}],
     "remainingRequired":["艺术鉴赏"],
     "courses":[
       {"courseId":"c1","courseName":"海洋科学","classIds":["j1"],"locations":["东校区"],"teachers":["甲"],
        "modules":["ocean"],"online":true,"credit":2,"score":88.5,"status":"passed","counted":true,"countedCredits":2,"attempts":[]},
       {"courseId":"c2","courseName":"音乐欣赏","classIds":["j2"],"locations":[],"teachers":[],
        "modules":["art"],"online":null,"credit":null,"score":null,"status":"review","counted":false,"countedCredits":0,
        "excludedReason":"缺少学分","attempts":[{"year":2025,"term":1,"classId":"j2","status":"review","matchedBy":null,
        "locations":[],"teachers":[],"modules":["art"],"online":false}]}],
     "issues":[{"code":"missing-credit","courseId":"c2","classId":"j2","message":"缺少学分"}],
     "isQualified":\(qualifiedJSON)}
    """
}

@Suite struct ElectiveProgressTests {
    @Test func decodesSchemaShape() throws {
        let p = try JSONDecoder().decode(ElectiveProgress.self, from: Data(sample().utf8))
        #expect(p.courses.count == 2 && p.courses[0].status == .passed && p.courses[1].online == nil)
        #expect(p.courses[1].attempts.first?.matchedBy == nil)
        #expect(p.stats.modules.ocean.credits == 2 && p.requirements.count == 3)
        #expect(p.computedDate != nil)
    }

    @Test func requirementFormatting() throws {
        let p = try JSONDecoder().decode(ElectiveProgress.self, from: Data(sample().utf8))
        #expect(ElectiveProgressDisplay.format(p.requirements[0]) == "4 / ≥6 学分")
        #expect(ElectiveProgressDisplay.format(p.requirements[1]) == "50% / ≤40%")
        #expect(ElectiveProgressDisplay.format(p.requirements[2]) == "2 / ≥2 个")
    }

    @Test func incompleteOrNullIsPendingNotFailed() throws {
        let incomplete = try JSONDecoder().decode(ElectiveProgress.self, from: Data(sample(complete: false, qualified: false, passed: false).utf8))
        #expect(incomplete.qualified == nil && incomplete.passed(incomplete.requirements[0]) == nil)
        let nullQualified = try JSONDecoder().decode(ElectiveProgress.self, from: Data(sample(qualified: nil).utf8))
        #expect(nullQualified.qualified == nil)
        let ok = try JSONDecoder().decode(ElectiveProgress.self, from: Data(sample(qualified: false, passed: false).utf8))
        #expect(ok.qualified == false && ok.passed(ok.requirements[0]) == false)
    }

    @Test func statusLabels() {
        #expect([.passed, .failed, .pending, .voided, .review].map(ElectiveProgressDisplay.statusLabel)
            == ["已及格", "未及格", "暂无成绩", "成绩作废", "待核对"])
    }

    @Test func fetchRejectsOtherAccountAndBadShape() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/elective-progress", json: Data(#"{"data":\#(sample())}"#.utf8))
        #expect(try await ElectiveProgressAPI(backend: mock).fetch(studentId: "2024000001").grade == 2024)
        await #expect(throws: GxuError.self) { _ = try await ElectiveProgressAPI(backend: mock).fetch(studentId: "2024000002") }
        mock.stub("GET /jw/elective-progress", json: Data(#"{"data":{"studentId":"2024000001"}}"#.utf8))
        await #expect(throws: GxuError.self) { _ = try await ElectiveProgressAPI(backend: mock).fetch(studentId: "2024000001") }
    }

    @Test func cacheIsPerStudent() throws {
        let store = InMemorySharedStore()
        let a = try JSONDecoder().decode(ElectiveProgress.self, from: Data(sample().utf8))
        try ElectiveProgressCache.save(store, a, studentId: "2024000001")
        #expect(ElectiveProgressCache.load(store, studentId: "2024000001") == a)
        #expect(ElectiveProgressCache.load(store, studentId: "2024000002") == nil)
        #expect(throws: GxuError.self) { try ElectiveProgressCache.save(store, a, studentId: "2024000002") }
    }
}
