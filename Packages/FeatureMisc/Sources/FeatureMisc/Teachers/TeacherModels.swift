import Foundation
import GxuFoundation
import GxuNetworking


public enum TeacherAvatarURL {
    public static func url(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed), components.host != nil else { return nil }
        if components.scheme == "http", let host = components.host, host == "gxu.edu.cn" || host.hasSuffix(".gxu.edu.cn") {
            components.scheme = "https"
        }
        return components.url
    }
}

public struct TeacherSummary: Decodable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var unit: String
    public var picURL: String

    public var avatarURL: URL? { TeacherAvatarURL.url(picURL) }

    public static func leader(_ leader: SchoolLeader) -> TeacherSummary {
        TeacherSummary(id: leader.id, name: leader.name, unit: SchoolLeaders.unit, picURL: leader.photoURL?.absoluteString ?? "")
    }

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
        public var name = "", sex = "", pic = "", politicalAffiliation = "", title = "", position = "", highestEducation = "", highestDegree = ""
        public var updatedAt: Int64?
        public var telephone = "", postalCode = "", email = "", qq = "", wechat = "", address = "", supervisor = ""
        public var disciplines: [Discipline] = []
        private enum CodingKeys: String, CodingKey {
            case name, sex, pic, politicalAffiliation, title, position, highestEducation, highestDegree, telephone, postalCode, email, qq, wechat, address, supervisor
            case supervisedDisciplines, updatedAt
        }
        public init() {}
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.text(.name); sex = c.text(.sex); pic = c.text(.pic); politicalAffiliation = c.text(.politicalAffiliation)
            title = c.text(.title); position = c.text(.position); highestEducation = c.text(.highestEducation); highestDegree = c.text(.highestDegree)
            telephone = c.text(.telephone); postalCode = c.text(.postalCode); email = c.text(.email); qq = c.text(.qq)
            wechat = c.text(.wechat); address = c.text(.address); supervisor = c.text(.supervisor)
            disciplines = (try? c.decodeIfPresent([Discipline].self, forKey: .supervisedDisciplines)) ?? []
            if let v = try? c.decodeIfPresent(Double.self, forKey: .updatedAt), v.isFinite, abs(v) < 1e15, v > 0 { updatedAt = Int64(v) }
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

public struct TeacherSection: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var text: String
}

public struct TeacherHeader: Equatable, Sendable {
    public var name: String
    public var badges: [String]
    public var infoLine: [String]
    public var address: String
    public var updatedAt: String

    public static func make(_ d: TeacherDetail, fallbackName: String, calendar: Calendar = .current) -> TeacherHeader {
        let sex = d.base.sex == "1" ? "男" : d.base.sex == "2" ? "女" : ""
        var updated = ""
        if let ms = d.base.updatedAt {
            let f = DateFormatter()
            f.calendar = calendar.gregorianLike
            f.timeZone = calendar.timeZone
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd HH:mm"
            updated = f.string(from: Date(timeIntervalSince1970: TimeInterval(ms) / 1000))
        }
        return TeacherHeader(
            name: d.base.name.isEmpty ? fallbackName : d.base.name,
            badges: [d.base.title, d.academic.employeeNumber].filter { !$0.isEmpty },
            infoLine: [sex, d.base.politicalAffiliation, d.base.position].filter { !$0.isEmpty },
            address: d.base.address, updatedAt: updated
        )
    }
}

extension Calendar {
    var gregorianLike: Calendar {
        if identifier == .gregorian { return self }
        var c = Calendar(identifier: .gregorian); c.timeZone = timeZone; c.locale = locale; return c
    }
}

public enum TeacherSections {
    public static func build(_ d: TeacherDetail) -> [TeacherSection] {
        func lines(_ pairs: [(String, String)]) -> String { pairs.filter { !$0.1.isEmpty }.map { "\($0.0)：\($0.1)" }.joined(separator: "\n") }
        let subjects = d.base.disciplines.compactMap { item -> String? in
            let parts = [("门类", item.category), ("一级学科", item.primary), ("二级学科", item.secondary)].filter { !$0.1.isEmpty }
            return parts.isEmpty ? nil : parts.map { "\($0.0)：\($0.1)" }.joined(separator: "，")
        }.joined(separator: "\n")
        let candidates: [TeacherSection] = [
            TeacherSection(id: "education", title: "学历与导师类型", text: lines([
                ("最后学位", d.base.highestDegree), ("学历信息", d.base.highestEducation),
                ("导师类别", d.base.supervisor.replacingOccurrences(of: ",", with: "、")),
            ])),
            TeacherSection(id: "subjects", title: "指导学科", text: subjects),
            TeacherSection(id: "contact", title: "联系方式", text: lines([
                ("邮政编码", d.base.postalCode), ("Email", d.base.email), ("联系电话", d.base.telephone), ("QQ", d.base.qq), ("微信", d.base.wechat),
            ])),
            TeacherSection(id: "introduction", title: "个人简介", text: d.academic.biography),
            TeacherSection(id: "courses", title: "主讲课程", text: d.academic.coursesTaught),
            TeacherSection(id: "projects", title: "主持（参与）的主要科研项目", text: d.academic.researchProjects),
            TeacherSection(id: "research", title: "主要研究方向", text: d.academic.researchDirections),
            TeacherSection(id: "papers", title: "论文", text: d.academic.papers),
            TeacherSection(id: "books", title: "著作", text: d.academic.books),
            TeacherSection(id: "patents", title: "专利", text: d.academic.patents),
            TeacherSection(id: "honors", title: "荣誉与获奖", text: d.academic.honorsAndAwards),
            TeacherSection(id: "admissions", title: "招生信息", text: d.academic.admissionsInformation),
            TeacherSection(id: "partTime", title: "学术兼职", text: d.academic.academicAppointments),
        ]
        return candidates.filter { !$0.text.isEmpty }
    }
}

public struct TeacherAPI: Sendable {
    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    public func search(_ keyword: String, page: Int = 1) async throws -> TeacherSearchPage {
        try await backend.getData("/teachers/search", query: ["q": keyword, "page": String(page)], auth: nil, as: TeacherSearchPage.self)
    }

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
