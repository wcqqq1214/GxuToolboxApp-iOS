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

    @Test func emptyFieldsAreHiddenNotPlaceholdered() throws {
        let d = try decode(TeacherDetail.self, """
        {"baseInfo":{"highestDegree":"博士","supervisedDisciplines":[{"disciplineCategory":"工学","primaryDiscipline":"","secondary":""},{"disciplineCategory":"","primaryDiscipline":"","secondary":""}]},
         "academicProfile":{"achievements":{"papers":"P1","books":"","patents":"Z1"}}}
        """)
        let sections = TeacherSections.build(d)
        #expect(sections.map(\.id) == ["education", "subjects", "papers", "patents"])
        #expect(sections[0].text == "最后学位：博士")
        #expect(sections[1].text == "门类：工学")
        #expect(sections.allSatisfy { !$0.text.isEmpty && !$0.text.contains("暂无") && !$0.text.contains("无") })
        #expect(TeacherSections.build(TeacherDetail()).isEmpty)
    }

    @Test func leadersDataIsComplete() {
        #expect(SchoolLeaders.all.map(\.title) == ["党委书记", "党委副书记", "校长", "副校长", "学术副校长", "党委常委", "校长助理"])
        #expect(SchoolLeaders.all.map { $0.leaders.count } == [1, 4, 1, 5, 1, 12, 4])
        let all = SchoolLeaders.all.flatMap(\.leaders)
        #expect(all.allSatisfy { !$0.name.isEmpty && !$0.position.isEmpty && !$0.duties.isEmpty })
        #expect(Set(all.map(\.id)).count == 16)
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

@Suite struct TeacherRealFixtureTests {
    @Test func searchPageMatchesRealShape() throws {
        let page = try JSONDecoder().decode(Envelope<TeacherSearchPage>.self, from: fixtureData("teachers-search")).data
        #expect(page.list.count == 12 && page.pages == 17 && page.total == 194)
        #expect(page.list.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty && !$0.unit.isEmpty })
        #expect(page.list.filter { $0.picURL.isEmpty }.count == 8)
        #expect(Set(page.list.map(\.id)).count == 12)
        #expect(page.list[0].unit == "校领导")
        #expect(page.list[1].unit.contains("（"))
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
        #expect(sections.map(\.id) == ["education", "subjects", "contact", "introduction", "courses", "research", "papers", "admissions", "partTime"])
        #expect(sections[0].text == "最后学位：博士\n学历信息：研究生\n导师类别：博士后合作导师、博士研究生导师、硕士研究生导师")
        #expect(sections[1].text == "门类：理学，一级学科：物理学\n门类：理学，一级学科：天文学")
        #expect(sections[2].text == "邮政编码：530004\nEmail：teacher01@example.invalid")
        #expect(sections.first { $0.id == "partTime" }?.text == "示例学术兼职1\n示例学术兼职2")
        #expect(sections.allSatisfy { !$0.text.contains("暂无") })
    }

    @Test func headerShowsOnlyWhatExists() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let d = try JSONDecoder().decode(Envelope<TeacherDetail>.self, from: fixtureData("teachers-profile")).data
        let h = TeacherHeader.make(d, fallbackName: "备用名", calendar: cal)
        #expect(h.name == "王测一" && h.badges == ["教授", "90009999"] && h.infoLine == ["男", "中共党员"])
        #expect(h.address == "示例路 1 号" && h.updatedAt == "2026-04-03 09:36")
        let sparse = try decode(TeacherDetail.self, #"{"baseInfo":{"name":"","sex":"2","title":"","employed":"1"},"academicProfile":{"employeeNumber":"900"}}"#)
        let s = TeacherHeader.make(sparse, fallbackName: "备用名", calendar: cal)
        #expect(s.name == "备用名" && s.badges == ["900"] && s.infoLine == ["女"] && s.address.isEmpty && s.updatedAt.isEmpty)
        let unknown = try decode(TeacherDetail.self, #"{"baseInfo":{"sex":"0"}}"#)
        #expect(TeacherHeader.make(unknown, fallbackName: "x", calendar: cal).infoLine.isEmpty)
    }

    @Test func sparseLeaderProfileDoesNotProduceEmptyBlocks() throws {
        let d = try decode(TeacherDetail.self, #"{"baseInfo":{"name":"领导甲","sex":"1","title":"教授","pic":"","employed":"1","updatedAt":1775180200000,"supervisedDisciplines":[]},"academicProfile":{"employeeNumber":"9001","biography":"","achievements":{"summary":"","papers":"","books":"","patents":""}}}"#)
        #expect(TeacherSections.build(d).isEmpty)
        #expect(TeacherHeader.make(d, fallbackName: "x").badges == ["教授", "9001"])
    }

    @Test func avatarURLsAreUpgradedToHTTPSOnlyForSchoolHosts() {
        #expect(TeacherAvatarURL.url("http://prof.gxu.edu.cn/teacher-info/user-images/a.jpg")?.absoluteString == "https://prof.gxu.edu.cn/teacher-info/user-images/a.jpg")
        #expect(TeacherAvatarURL.url("https://www.gxu.edu.cn/__local/a.png")?.absoluteString == "https://www.gxu.edu.cn/__local/a.png")
        #expect(TeacherAvatarURL.url("http://other.example.com/a.jpg")?.scheme == "http")
        #expect(TeacherAvatarURL.url("") == nil && TeacherAvatarURL.url("  ") == nil && TeacherAvatarURL.url("not a url") == nil)
        #expect(TeacherSummary(id: "1", name: "甲", unit: "u", picURL: "http://prof.gxu.edu.cn/x.jpg").avatarURL?.scheme == "https")
        #expect(TeacherSummary(id: "1", name: "甲", unit: "u", picURL: "").avatarURL == nil)
    }

    @Test func leaderNavigationParameters() async throws {
        #expect(SchoolLeaders.unit == "校领导")
        for leader in SchoolLeaders.all.flatMap(\.leaders) {
            let t = TeacherSummary.leader(leader)
            #expect(t.name == leader.name && t.unit == "校领导" && !t.id.isEmpty)
            #expect(t.avatarURL?.scheme == "https")
        }
        let mock = MockBackendAPI()
        mock.stub("GET /teachers/profile", json: Data(#"{"data":{"baseInfo":{"name":"徐华蕊"},"academicProfile":{}}}"#.utf8))
        let leader = SchoolLeaders.all[0].leaders[0]
        let d = try await TeacherAPI(backend: mock).profile(name: leader.name, unit: TeacherSummary.leader(leader).unit)
        #expect(d?.base.name == "徐华蕊")
    }
}
