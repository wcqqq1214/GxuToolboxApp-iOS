import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureCourse

// 构造样例按 RN v2.2 `schema/progress.ts` 写（虚构学号和课程），用来覆盖真实样本没有的分支（达标 / 未达标 / ratio）；真实响应见文末 ElectiveProgressFixtureTests。
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

// 真实脱敏响应（A 抓取，`Fixtures/sanitized/elective-progress.json`）；期望值由 Python 对同一份数据独立算出。
@Suite struct ElectiveProgressFixtureTests {
    private struct Envelope: Decodable { var data: ElectiveProgress }

    private func real() throws -> ElectiveProgress {
        let url = try #require(Bundle.module.url(forResource: "elective-progress", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url)).data
    }

    @Test func decodesRealResponse() throws {
        let p = try real()
        #expect(p.courses.count == 12 && p.requirements.count == 7 && p.issues.count == 1)
        #expect(p.computedDate != nil)
        #expect(p.courses.reduce(0) { $0 + $1.countedCredits } == p.stats.totalCredits)
        #expect(p.courses.contains { $0.status == .review && $0.credit == nil && $0.online == nil && $0.excludedReason != nil })
    }

    @Test func incompleteAccountShowsPending() throws {
        let p = try real()
        #expect(!p.complete && p.isQualified == nil && p.qualified == nil)
        #expect(p.requirements.allSatisfy { p.passed($0) == nil })
        #expect(p.requirements.map(ElectiveProgressDisplay.format).prefix(2) == ["11.5 / ≥10 学分", "6.5 / ≥5 学分"])
        #expect(ElectiveProgressDisplay.format(p.requirements[5]) == "3 / ≥2 个")
    }

    @Test func apiAcceptsRealResponseForMatchingStudent() async throws {
        let p = try real()
        let mock = MockBackendAPI()
        let url = try #require(Bundle.module.url(forResource: "elective-progress", withExtension: "json", subdirectory: "Fixtures"))
        mock.stub("GET /jw/elective-progress", json: try Data(contentsOf: url))
        #expect(try await ElectiveProgressAPI(backend: mock).fetch(studentId: p.studentId) == p)
        await #expect(throws: GxuError.self) { _ = try await ElectiveProgressAPI(backend: mock).fetch(studentId: "other") }
    }
}
