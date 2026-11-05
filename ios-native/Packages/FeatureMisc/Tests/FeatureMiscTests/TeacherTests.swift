import Foundation
import GxuFoundation
import GxuTestSupport
import Testing
@testable import FeatureMisc

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

@Suite struct TeacherModelTests {
    @Test func searchPageDecodesAndTolerates() throws {
        let page = try decode(TeacherSearchPage.self, #"{"list":[{"id":"1","name":"张三","unit":"计算机学院","picUrl":"https://x/y.png"},{"id":2,"name":"李四"}],"pages":"3","total":41}"#)
        #expect(page.list.count == 2 && page.list[1].id == "2" && page.list[1].unit == "")
        #expect(page.pages == 3 && page.total == 41)
        let empty = try decode(TeacherSearchPage.self, #"{}"#)
        #expect(empty.list.isEmpty && empty.pages == 0 && empty.total == 0)
    }

    @Test func detailDecodesNested() throws {
        let d = try decode(TeacherDetail.self, """
        {"baseInfo":{"name":"张三","title":"教授","highestDegree":"博士","email":"a@b.c","supervisedDisciplines":[{"disciplineCategory":"工学","primaryDiscipline":"计算机科学与技术","secondary":""}]},
         "academicProfile":{"biography":"简介","achievements":{"papers":"P1\\nP2","books":"","patents":"Z1"}}}
        """)
        #expect(d.base.title == "教授" && d.base.disciplines.count == 1)
        #expect(d.academic.papers == "P1\nP2" && d.academic.patents == "Z1" && d.academic.books == "")
        #expect(try decode(TeacherDetail.self, #"{}"#).base.name == "")
    }

    @Test func sectionsFillBlanksAndOrderAchievements() throws {
        let d = try decode(TeacherDetail.self, """
        {"baseInfo":{"highestDegree":"博士","supervisedDisciplines":[{"disciplineCategory":"工学","primaryDiscipline":"","secondary":""}]},
         "academicProfile":{"achievements":{"papers":"P1","books":"","patents":"Z1"}}}
        """)
        let sections = TeacherSections.build(d)
        #expect(sections.map(\.id) == ["education", "subjects", "contact", "introduction", "courses", "projects", "research", "papers", "patents", "honors", "admissions", "partTime"])
        #expect(sections[0].text == "最后学位：博士\n学历信息：暂无信息\n导师类别：暂无信息")
        #expect(sections[1].text == "门类：工学，一级学科：无，二级学科：无")
        #expect(sections[3].text == "暂无信息")
        #expect(sections.first { $0.id == "papers" }?.title == "论文")
        #expect(sections.first { $0.id == "patents" }?.title == "专利")
        // 三项成果都空：写一条"暂无信息"
        let none = TeacherSections.build(TeacherDetail())
        #expect(none.first { $0.id == "achievements" }?.text == "暂无信息")
        #expect(none.first { $0.id == "subjects" }?.text == "暂无信息")
    }

    @Test func leadersDataIsComplete() {
        #expect(SchoolLeaders.all.map(\.title) == ["党委书记", "党委副书记", "校长", "副校长", "学术副校长", "党委常委", "校长助理"])
        #expect(SchoolLeaders.all.map { $0.leaders.count } == [1, 4, 1, 5, 1, 12, 4])
        let all = SchoolLeaders.all.flatMap(\.leaders)
        #expect(all.allSatisfy { !$0.name.isEmpty && !$0.position.isEmpty && !$0.duties.isEmpty })
        #expect(Set(all.map(\.id)).count == 16)   // 兼任多个栏目的人重复出现，但一共 16 位
    }
}

@Suite struct TeacherAPITests {
    @Test func searchAndProfileCallEndpoints() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /teachers/search", json: Data(#"{"data":{"list":[{"id":"1","name":"张三","unit":"计算机学院"}],"pages":2,"total":9}}"#.utf8))
        mock.stub("GET /teachers/profile", json: Data(#"{"data":null}"#.utf8))
        let api = TeacherAPI(backend: mock)
        let page = try await api.search("张三")
        #expect(page.total == 9 && page.list.first?.name == "张三")
        #expect(try await api.profile(name: "张三", unit: "计算机学院") == nil)
        #expect(mock.calls.contains { $0.contains("/teachers/search") })
    }

    @Test func networkErrorPropagates() async {
        let mock = MockBackendAPI()
        mock.stub("GET /teachers/search", error: GxuError.network("offline"))
        await #expect(throws: GxuError.network("offline")) { _ = try await TeacherAPI(backend: mock).search("x") }
    }
}

private func fixtureData(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private struct Envelope<T: Decodable>: Decodable { var data: T }

/// 真实脱敏响应（A 抓取）：第 1 页 12 条，共 194 条 / 17 页；姓名、联系方式等已替换，结构不变。
@Suite struct TeacherRealFixtureTests {
    @Test func searchPageMatchesRealShape() throws {
        let page = try JSONDecoder().decode(Envelope<TeacherSearchPage>.self, from: fixtureData("teachers-search")).data
        #expect(page.list.count == 12 && page.pages == 17 && page.total == 194)
        #expect(page.list.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty && !$0.unit.isEmpty })
        #expect(page.list.filter { $0.picURL.isEmpty }.count == 8)   // 没有头像的是空串，不是 null
        #expect(Set(page.list.map(\.id)).count == 12)
        #expect(page.list[0].unit == "校领导")
        #expect(page.list[1].unit.contains("（"))                   // 单位名里有括号和顿号
    }

    @Test func profileMatchesRealShape() throws {
        let d = try JSONDecoder().decode(Envelope<TeacherDetail>.self, from: fixtureData("teachers-profile")).data
        #expect(d.base.title == "教授" && d.base.highestDegree == "博士" && d.base.highestEducation == "研究生")
        #expect(d.base.supervisor == "博士后合作导师,博士研究生导师,硕士研究生导师")
        #expect(d.base.disciplines.map(\.primary) == ["物理学", "天文学"])
        #expect(d.base.disciplines.allSatisfy { $0.category == "理学" && $0.secondary.isEmpty })
        #expect(d.base.telephone.isEmpty && d.base.qq.isEmpty && d.base.position.isEmpty)
        #expect(d.base.postalCode == "530004")
        #expect(d.academic.coursesTaught.split(separator: "\n").count == 6)
        #expect(d.academic.papers == "示例papers" && d.academic.books.isEmpty && d.academic.patents.isEmpty)
        #expect(d.academic.researchProjects.isEmpty)
    }

    @Test func sectionsFromRealProfile() throws {
        let d = try JSONDecoder().decode(Envelope<TeacherDetail>.self, from: fixtureData("teachers-profile")).data
        let sections = TeacherSections.build(d)
        // 成果只有"论文"一项，著作和专利是空串，不显示
        #expect(sections.map(\.id) == ["education", "subjects", "contact", "introduction", "courses", "projects", "research", "papers", "honors", "admissions", "partTime"])
        #expect(sections[0].text == "最后学位：博士\n学历信息：研究生\n导师类别：博士后合作导师,博士研究生导师,硕士研究生导师")
        #expect(sections[1].text == "门类：理学，一级学科：物理学，二级学科：无\n门类：理学，一级学科：天文学，二级学科：无")
        #expect(sections[2].text == "邮政编码：530004\nEmail：teacher01@example.invalid\n联系电话：暂无信息\nQQ：暂无信息\n微信：暂无信息")
        #expect(sections.first { $0.id == "projects" }?.text == "暂无信息")
        #expect(sections.first { $0.id == "honors" }?.text == "暂无信息")
        #expect(sections.first { $0.id == "partTime" }?.text == "示例学术兼职1\n示例学术兼职2")
    }
}
