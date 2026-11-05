import Foundation
import GxuFoundation
import GxuNetworking

// 教师信息：后端 `GET /teachers/search?q=&page=`、`GET /teachers/profile?name=&school=`（`{code, data, message}`，`getData` 解掉外层）。
// TODO(verify): 没有校园网 / 真实响应，字段按 RN 的类型定义（teachersInfo/type/info.ts）写，解码都宽容；用 Mock 和单测验证，**后续测试**。

public struct TeacherSummary: Decodable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var unit: String
    public var picURL: String

    public init(id: String, name: String, unit: String, picURL: String = "") {
        self.id = id
        self.name = name
        self.unit = unit
        self.picURL = picURL
    }

    private enum CodingKeys: String, CodingKey { case id, name, unit, picUrl }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.text(.id)
        name = c.text(.name)
        unit = c.text(.unit)
        picURL = c.text(.picUrl)
    }
}

public struct TeacherSearchPage: Decodable, Sendable {
    public var list: [TeacherSummary]
    public var pages: Int
    public var total: Int

    private enum CodingKeys: String, CodingKey { case list, pages, total }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decodeIfPresent([TeacherSummary].self, forKey: .list)) ?? []
        pages = c.int(.pages) ?? 0
        total = c.int(.total) ?? list.count
    }
}

public struct TeacherDetail: Decodable, Sendable, Hashable {
    public struct Discipline: Decodable, Sendable, Hashable {
        public var category: String, primary: String, secondary: String
        private enum CodingKeys: String, CodingKey { case disciplineCategory, primaryDiscipline, secondary }
        public init(category: String = "", primary: String = "", secondary: String = "") {
            self.category = category; self.primary = primary; self.secondary = secondary
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            category = c.text(.disciplineCategory); primary = c.text(.primaryDiscipline); secondary = c.text(.secondary)
        }
    }

    public struct Base: Decodable, Sendable, Hashable {
        public var name = "", sex = "", pic = "", politicalAffiliation = "", title = "", highestEducation = "", highestDegree = ""
        public var telephone = "", postalCode = "", email = "", qq = "", wechat = "", address = "", supervisor = ""
        public var disciplines: [Discipline] = []
        private enum CodingKeys: String, CodingKey {
            case name, sex, pic, politicalAffiliation, title, highestEducation, highestDegree, telephone, postalCode, email, qq, wechat, address, supervisor
            case supervisedDisciplines
        }
        public init() {}
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.text(.name); sex = c.text(.sex); pic = c.text(.pic); politicalAffiliation = c.text(.politicalAffiliation)
            title = c.text(.title); highestEducation = c.text(.highestEducation); highestDegree = c.text(.highestDegree)
            telephone = c.text(.telephone); postalCode = c.text(.postalCode); email = c.text(.email); qq = c.text(.qq)
            wechat = c.text(.wechat); address = c.text(.address); supervisor = c.text(.supervisor)
            disciplines = (try? c.decodeIfPresent([Discipline].self, forKey: .supervisedDisciplines)) ?? []
        }
    }

    public struct Academic: Decodable, Sendable, Hashable {
        public var employeeNumber = "", biography = "", coursesTaught = "", researchProjects = "", researchDirections = ""
        public var papers = "", books = "", patents = ""
        public var honorsAndAwards = "", admissionsInformation = "", academicAppointments = ""
        private enum CodingKeys: String, CodingKey {
            case employeeNumber, biography, coursesTaught, researchProjects, researchDirections, achievements
            case honorsAndAwards, admissionsInformation, academicAppointments
        }
        private enum AchievementKeys: String, CodingKey { case papers, books, patents }
        public init() {}
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            employeeNumber = c.text(.employeeNumber); biography = c.text(.biography); coursesTaught = c.text(.coursesTaught)
            researchProjects = c.text(.researchProjects); researchDirections = c.text(.researchDirections)
            honorsAndAwards = c.text(.honorsAndAwards); admissionsInformation = c.text(.admissionsInformation)
            academicAppointments = c.text(.academicAppointments)
            if let a = try? c.nestedContainer(keyedBy: AchievementKeys.self, forKey: .achievements) {
                papers = a.text(.papers); books = a.text(.books); patents = a.text(.patents)
            }
        }
    }

    public var base: Base
    public var academic: Academic

    public init(base: Base = Base(), academic: Academic = Academic()) {
        self.base = base
        self.academic = academic
    }

    private enum CodingKeys: String, CodingKey { case baseInfo, academicProfile }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = (try? c.decodeIfPresent(Base.self, forKey: .baseInfo)) ?? Base()
        academic = (try? c.decodeIfPresent(Academic.self, forKey: .academicProfile)) ?? Academic()
    }
}

/// 详情页的「标题 + 文本」分组（移植自 RN `buildSections`）：空值统一写"暂无信息"
public struct TeacherSection: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var text: String
}

public enum TeacherSections {
    private static let none = "暂无信息"
    private static func or(_ s: String) -> String { s.isEmpty ? none : s }

    public static func build(_ d: TeacherDetail) -> [TeacherSection] {
        let subjects = d.base.disciplines.map {
            "门类：\($0.category.isEmpty ? "无" : $0.category)，一级学科：\($0.primary.isEmpty ? "无" : $0.primary)，二级学科：\($0.secondary.isEmpty ? "无" : $0.secondary)"
        }.joined(separator: "\n")
        let education = ["最后学位：\(or(d.base.highestDegree))", "学历信息：\(or(d.base.highestEducation))", "导师类别：\(or(d.base.supervisor))"].joined(separator: "\n")
        let contact = ["邮政编码：\(or(d.base.postalCode))", "Email：\(or(d.base.email))", "联系电话：\(or(d.base.telephone))", "QQ：\(or(d.base.qq))", "微信：\(or(d.base.wechat))"].joined(separator: "\n")
        // RN 把"论文 / 著作 / 专利"当三个并列分组，没有成果时整块标题"取得的主要成果"下面是空的；这里空的成果项直接不显示，三项都空时才写"暂无信息"
        let achievements: [TeacherSection] = [
            TeacherSection(id: "papers", title: "论文", text: d.academic.papers),
            TeacherSection(id: "books", title: "著作", text: d.academic.books),
            TeacherSection(id: "patents", title: "专利", text: d.academic.patents),
        ].filter { !$0.text.isEmpty }
        return [
            TeacherSection(id: "education", title: "学历与导师类型", text: education),
            TeacherSection(id: "subjects", title: "指导学科", text: or(subjects)),
            TeacherSection(id: "contact", title: "联系方式", text: contact),
            TeacherSection(id: "introduction", title: "个人简介", text: or(d.academic.biography)),
            TeacherSection(id: "courses", title: "主讲课程", text: or(d.academic.coursesTaught)),
            TeacherSection(id: "projects", title: "主持（参与）的主要科研项目", text: or(d.academic.researchProjects)),
            TeacherSection(id: "research", title: "主要研究方向", text: or(d.academic.researchDirections)),
        ] + (achievements.isEmpty ? [TeacherSection(id: "achievements", title: "取得的主要成果", text: none)] : achievements) + [
            TeacherSection(id: "honors", title: "荣誉与获奖", text: or(d.academic.honorsAndAwards)),
            TeacherSection(id: "admissions", title: "招生信息", text: or(d.academic.admissionsInformation)),
            TeacherSection(id: "partTime", title: "学术兼职", text: or(d.academic.academicAppointments)),
        ]
    }
}

public struct TeacherAPI: Sendable {
    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    func search(_ keyword: String, page: Int = 1) async throws -> TeacherSearchPage {
        try await backend.getData("/teachers/search", query: ["q": keyword, "page": String(page)], auth: nil, as: TeacherSearchPage.self)
    }

    /// `data` 为 null 返回 nil（"暂无教师信息"）
    func profile(name: String, unit: String) async throws -> TeacherDetail? {
        try await backend.getData("/teachers/profile", query: ["name": name, "school": unit], auth: nil, as: TeacherDetail?.self)
    }
}

extension KeyedDecodingContainer {
    func text(_ key: Key) -> String {
        if let v = try? decodeIfPresent(String.self, forKey: key) { return v.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return String(v) }
        return ""
    }

    func int(_ key: Key) -> Int? {
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(String.self, forKey: key) { return Int(v.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
}
