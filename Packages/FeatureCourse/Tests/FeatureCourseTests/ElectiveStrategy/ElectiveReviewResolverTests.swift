import ExamKit
import Foundation
import Testing
@testable import FeatureCourse

@Suite struct ElectiveReviewResolverTests {
    private struct Envelope<T: Decodable>: Decodable { var data: T }
    private struct Page: Decodable { var items: [Score] }

    private func load<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Envelope<T>.self, from: Data(contentsOf: url)).data
    }

    private func progress() throws -> ElectiveProgress { try load(ElectiveProgress.self, "elective-progress") }
    private func scores() throws -> [Score] { try load(Page.self, "score").items }
    private let ocean = "海洋与人类文明"

    @Test func fixtureHasExactlyOneReviewCourse() throws {
        let p = try progress()
        #expect(p.courses.filter { $0.status == .review }.map(\.courseName) == [ocean])
        #expect(p.issues.count == 1 && !p.complete && p.isQualified == nil)
    }

    @Test func confirmsFromScoreRecordAndRecomputes() throws {
        let before = try progress()
        let r = ElectiveReviewResolver.resolve(before, scores: try scores())
        let course = try #require(r.progress.courses.first { $0.courseName == ocean })
        #expect(course.status == .passed && course.score == 88 && course.credit == 1 && course.counted && course.countedCredits == 1)
        #expect(course.excludedReason == nil && course.online == true)
        #expect(r.confirmed[course.id] == "已按成绩记录核对" && r.unresolved.isEmpty)
        #expect(r.progress.issues.isEmpty)
        #expect(r.progress.stats.totalCredits == 12.5 && r.progress.stats.offlineCredits == 6.5)
        #expect(r.progress.stats.modules.ocean == .init(credits: 2, courseCount: 2))
        #expect(r.progress.stats.modules.lead == before.stats.modules.lead && r.progress.stats.modules.art == before.stats.modules.art)
        #expect(r.progress.complete && r.progress.isQualified == true && r.progress.qualified == true)
        #expect(r.progress.requirements.map(\.passed) == Array(repeating: true, count: 7))
        #expect(r.progress.requirements.first { $0.key == "totalCredits" }?.actual == 12.5)
        #expect(r.progress.courses.filter { $0.courseName != ocean } == before.courses.filter { $0.courseName != ocean })
    }

    @Test func recomputeOnUnchangedDataMatchesBackendNumbers() throws {
        var p = try progress()
        p.courses.removeAll { $0.status == .review }
        p.issues = []
        var ok = p.courses
        ok.append(try #require(try progress().courses.first { $0.status == .review }))
        p.courses = ok
        let r = ElectiveReviewResolver.resolve(p, scores: [Score(id: "x", year: 2022, term: 0, courseName: ocean, credit: 1, score: 88)])
        let original = try progress()
        #expect(r.progress.stats.modules.lead == original.stats.modules.lead)
        #expect(r.progress.stats.modules.entrepreneurship == original.stats.modules.entrepreneurship)
        #expect(r.progress.stats.modules.asean == original.stats.modules.asean && r.progress.stats.modules.ethnic == original.stats.modules.ethnic)
        #expect(r.progress.requirements.first { $0.key == "lead" }?.actual == 4)
    }

    private func reason(_ scores: [Score]?) throws -> String? {
        let r = ElectiveReviewResolver.resolve(try progress(), scores: scores)
        #expect(!r.progress.complete && r.progress.isQualified == nil && r.confirmed.isEmpty)
        return r.unresolved.values.first
    }

    private func oceanScore(id: String = "z", year: Int = 2022, term: Int = 0, credit: Double? = 1, score: Double? = 88) -> Score {
        Score(id: id, year: year, term: term, courseName: ocean, credit: credit, score: score)
    }

    @Test func unresolvedKeepsReviewWithSpecificReason() throws {
        let others = try scores().filter { $0.courseName != ocean }
        #expect(try reason(others) == "成绩记录里没有这门课")
        #expect(try reason(others + [oceanScore(credit: 2)]) == "成绩记录里这门课的学分与选课记录不一致")
        #expect(try reason(others + [oceanScore(year: 2023)]) == "成绩记录里没有2022学年对应学期的这门课")
        #expect(try reason(others + [oceanScore(term: 1)]) == "成绩记录里没有2022学年对应学期的这门课")
        #expect(try reason(others + [oceanScore(score: nil)]) == "成绩记录里这门课还没有成绩")
        #expect(try reason(others + [oceanScore(id: "a"), oceanScore(id: "b", score: 70)]) == "成绩记录里有多条同名同学分的记录，无法确定对应哪一条")
        #expect(try reason(nil) == "成绩记录暂时无法读取，无法核对")
        #expect(try reason([]) == "成绩记录暂时无法读取，无法核对")
        let text = try #require(try reason(others))
        #expect(!text.contains("歧义"))
    }

    @Test func sameRecordRepeatedIsStillUnique() throws {
        let others = try scores().filter { $0.courseName != ocean }
        let r = ElectiveReviewResolver.resolve(try progress(), scores: others + [oceanScore(id: "same"), oceanScore(id: "same")])
        #expect(r.confirmed.count == 1)
    }

    @Test func failingScoreIsConfirmedButNotCounted() throws {
        let others = try scores().filter { $0.courseName != ocean }
        let r = ElectiveReviewResolver.resolve(try progress(), scores: others + [oceanScore(score: 55)])
        let course = try #require(r.progress.courses.first { $0.courseName == ocean })
        #expect(course.status == .failed && !course.counted && course.countedCredits == 0)
        #expect(r.progress.stats.totalCredits == 11.5 && r.progress.stats.modules.ocean == .init(credits: 1, courseCount: 1))
    }

    @Test func otherIssuesKeepResultIncomplete() throws {
        var p = try progress()
        p.issues.append(.init(code: "other", courseId: "zzz", classId: "q", message: "别的问题"))
        let r = ElectiveReviewResolver.resolve(p, scores: try scores())
        #expect(r.progress.issues.count == 1 && !r.progress.complete && r.progress.isQualified == nil)
    }

    @Test func newlyCoveredSpecialModuleNeedsBackend() throws {
        var p = try progress()
        p.stats.modules.ocean = .init(credits: 0, courseCount: 0)
        let r = ElectiveReviewResolver.resolve(p, scores: try scores())
        #expect(r.confirmed.count == 1 && !r.progress.complete && r.progress.isQualified == nil)
    }

    @Test func noReviewCourseLeavesProgressUntouched() throws {
        var p = try progress()
        for i in p.courses.indices where p.courses[i].status == .review { p.courses[i].status = .passed }
        let r = ElectiveReviewResolver.resolve(p, scores: try scores())
        #expect(r.progress == p && r.confirmed.isEmpty && r.unresolved.isEmpty)
    }
}
