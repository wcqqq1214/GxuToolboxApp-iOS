import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureCourse

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

@Suite struct EvaluationTaskTests {
    @Test func decodesBothNamingStyles() throws {
        let camel = try decode(EvaluationTask.self, #"{"teacherName":"甲","courseName":"高数","courseTypeName":"理论","submitStatus":"未评","teachingClassId":"j1","courseId":"k1"}"#)
        let raw = try decode(EvaluationTask.self, #"{"jzgmc":"乙","kcmc":"英语","xsmc":"实践","tjztmc":"已评完","jxb_id":"j2","kch_id":"k2"}"#)
        #expect(camel.status == .pending && camel.teacherName == "甲" && camel.teachingClassId == "j1")
        #expect(raw.status == .done && raw.courseName == "英语" && raw.courseTypeName == "实践")
        #expect(try decode(EvaluationTask.self, #"{}"#).status == .other)
    }

    @Test func sortsTodoFirstAndCounts() {
        let tasks = [("a", "已评完"), ("b", "未评"), ("c", "未评完"), ("d", "未评"), ("e", "状态未知")]
            .map { EvaluationTask(teacherName: $0.0, courseName: $0.0, submitStatus: $0.1) }
        let sorted = EvaluationSummary.sorted(tasks)
        #expect(sorted.map(\.teacherName) == ["b", "d", "c", "a", "e"])
        let s = EvaluationSummary(tasks)
        #expect(s.pending == 2 && s.partial == 1 && s.done == 1 && s.total == 4)
    }

    @Test func apiReturnsEmptyOnNullData() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/evaluation", json: Data(#"{"data":null}"#.utf8))
        #expect(try await EvaluationAPI(backend: mock).tasks().isEmpty)
        mock.stub("GET /jw/evaluation", json: Data(#"{"data":[{"teacherName":"甲","courseName":"高数","submitStatus":"未评"}]}"#.utf8))
        #expect(try await EvaluationAPI(backend: mock).tasks().count == 1)
    }

    @Test func missingBackendRouteGetsReadableMessage() {
        let message = EvaluationAPI.message(for: .http(status: 404, message: "Cannot GET /jw/evaluation"))
        #expect(message.contains("暂未开放"))
        #expect(EvaluationAPI.message(for: .network("x")) == GxuError.network("x").userMessage)
    }

    @Test func apiPropagatesSessionExpired() async {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/evaluation", error: GxuError.sessionExpired(.jw))
        await #expect(throws: GxuError.sessionExpired(.jw)) { _ = try await EvaluationAPI(backend: mock).tasks() }
    }
}

@Suite struct EvaluationTemplateTests {
    private func repo() throws -> EvaluationTemplateRepository {
        EvaluationTemplateRepository(database: try AppDatabase.inMemory(features: [CourseFeature.migrations]))
    }

    @Test func questionStructureIsConsistent() {
        #expect(EvaluationQuestions.items.count == 16)
        #expect(EvaluationQuestions.categorySizes.reduce(0, +) == EvaluationQuestions.items.count)
        #expect(EvaluationQuestions.levels.count == 5)
        #expect(EvaluationQuestions.defaultAnswers == Array(repeating: 1, count: 16))
    }

    @Test func answersAreNormalized() {
        #expect(EvaluationTemplate(name: "x", answers: []).answers == EvaluationQuestions.defaultAnswers)
        #expect(EvaluationTemplate(name: "x", answers: [0, 9, -1, 4]).answers.prefix(4) == [0, 1, 1, 4])
        #expect(EvaluationTemplate(name: "x", answers: Array(repeating: 2, count: 40)).answers.count == 16)
    }

    @Test func createUpdateDeleteRoundTrip() async throws {
        let repo = try repo()
        var t = EvaluationTemplate(name: "全部满意", comment: "很好")
        t.answers[3] = 0
        let saved = try await repo.save(t, studentId: "s1", now: Date(timeIntervalSince1970: 100))
        #expect(saved.id != nil)
        var list = try await repo.list(studentId: "s1")
        #expect(list.count == 1 && list[0].answers[3] == 0 && list[0].comment == "很好")

        var edited = list[0]
        edited.name = "改名"; edited.comment = "更新"
        try await repo.save(edited, studentId: "s1", now: Date(timeIntervalSince1970: 200))
        list = try await repo.list(studentId: "s1")
        #expect(list.count == 1 && list[0].name == "改名" && list[0].comment == "更新")

        try await repo.delete(id: list[0].id!, studentId: "s1")
        #expect(try await repo.list(studentId: "s1").isEmpty)
    }

    @Test func rejectsEmptyAndDuplicateNames() async throws {
        let repo = try repo()
        await #expect(throws: GxuError.invalidData("请输入模板名称")) { _ = try await repo.save(EvaluationTemplate(name: "  "), studentId: "s1") }
        try await repo.save(EvaluationTemplate(name: "A"), studentId: "s1")
        await #expect(throws: GxuError.self) { _ = try await repo.save(EvaluationTemplate(name: "A"), studentId: "s1") }
        let b = try await repo.save(EvaluationTemplate(name: "B"), studentId: "s1")
        try await repo.save(b, studentId: "s1")
        var clash = b
        clash.name = "A"
        await #expect(throws: GxuError.self) { _ = try await repo.save(clash, studentId: "s1") }
    }

    @Test func isolatedByStudentAndOrderedByRecentEdit() async throws {
        let repo = try repo()
        try await repo.save(EvaluationTemplate(name: "old"), studentId: "s1", now: Date(timeIntervalSince1970: 10))
        try await repo.save(EvaluationTemplate(name: "new"), studentId: "s1", now: Date(timeIntervalSince1970: 20))
        try await repo.save(EvaluationTemplate(name: "other"), studentId: "s2")
        #expect(try await repo.list(studentId: "s1").map(\.name) == ["new", "old"])
        #expect(try await repo.list(studentId: "s2").map(\.name) == ["other"])
        try await repo.save(EvaluationTemplate(name: "old"), studentId: "s2")
        let victim = try await repo.list(studentId: "s1")[0]
        await #expect(throws: GxuError.self) { _ = try await repo.save(victim, studentId: "s2") }
        try await repo.delete(id: victim.id!, studentId: "s2")
        #expect(try await repo.list(studentId: "s1").count == 2)
    }

    @Test func corruptedAnswersFallBackToDefault() async throws {
        let db = try AppDatabase.inMemory(features: [CourseFeature.migrations])
        try await db.writer.write { d in
            try d.execute(sql: "INSERT INTO evaluation_template (studentId, name, answersJSON, comment, updatedAt) VALUES ('s1','坏数据','not json','',0)")
        }
        let list = try await EvaluationTemplateRepository(database: db).list(studentId: "s1")
        #expect(list.first?.answers == EvaluationQuestions.defaultAnswers)
    }
}
