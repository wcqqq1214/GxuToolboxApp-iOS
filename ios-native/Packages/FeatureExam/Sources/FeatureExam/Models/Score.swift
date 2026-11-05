import Foundation

/// `GET /jw/score` 返回的一门课成绩
public struct Score: Codable, Hashable, Sendable, Identifiable {
    /// 教学班 ID（jxb_id），同时是平时分接口的 `id`
    public var id: String
    public var year: Int
    /// 1 秋 / 2 春；小学期等其他学期为 0
    public var term: Int
    public var courseName: String
    /// 无法解析时为 nil
    public var credit: Double?
    /// 等级制成绩由后端换算成数字；两者都不是数字时为 nil
    public var score: Double?
    public var teacherName: String
    /// `yyyy-MM-dd HH:mm:ss`
    public var uploadAt: String

    public init(
        id: String, year: Int, term: Int, courseName: String,
        credit: Double?, score: Double?, teacherName: String = "", uploadAt: String = ""
    ) {
        self.id = id
        self.year = year
        self.term = term
        self.courseName = courseName
        self.credit = credit
        self.score = score
        self.teacherName = teacherName
        self.uploadAt = uploadAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, year, term, credit, score
        case courseName = "course_name"
        case teacherName = "teacher_name"
        case uploadAt = "upload_at"
        // TODO(verify): 后端是否同时返回 camelCase 副本；这里只在 snake_case 缺失时回退
        case courseNameCamel = "courseName"
        case teacherNameCamel = "teacherName"
        case uploadAtCamel = "uploadAt"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        year = try c.decode(Int.self, forKey: .year)
        term = try c.decodeIfPresent(Int.self, forKey: .term) ?? 0
        courseName = try c.decodeIfPresent(String.self, forKey: .courseName)
            ?? c.decodeIfPresent(String.self, forKey: .courseNameCamel) ?? ""
        credit = try c.decodeIfPresent(Double.self, forKey: .credit)
        score = try c.decodeIfPresent(Double.self, forKey: .score)
        teacherName = try c.decodeIfPresent(String.self, forKey: .teacherName)
            ?? c.decodeIfPresent(String.self, forKey: .teacherNameCamel) ?? ""
        uploadAt = try c.decodeIfPresent(String.self, forKey: .uploadAt)
            ?? c.decodeIfPresent(String.self, forKey: .uploadAtCamel) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(year, forKey: .year)
        try c.encode(term, forKey: .term)
        try c.encode(courseName, forKey: .courseName)
        try c.encodeIfPresent(credit, forKey: .credit)
        try c.encodeIfPresent(score, forKey: .score)
        try c.encode(teacherName, forKey: .teacherName)
        try c.encode(uploadAt, forKey: .uploadAt)
    }
}

/// `GET /jw/score` 的 `data`
struct ScorePage: Decodable, Sendable {
    var items: [Score]
}

/// 平时成绩明细的一项（`GET /jw/score/usual`）
public struct UsualScoreItem: Codable, Hashable, Sendable {
    /// 如"平时成绩""期末成绩""总评"
    public var name: String
    /// 不带 % 的字符串；总评等没有比例时为 "N/A"
    public var ratio: String
    public var score: String

    public init(name: String, ratio: String, score: String) {
        self.name = name
        self.ratio = ratio
        self.score = score
    }

    public var hasRatio: Bool { ratio != "N/A" }
}
