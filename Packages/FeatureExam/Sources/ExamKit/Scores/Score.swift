import Foundation

public struct Score: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var year: Int
    public var term: Int
    public var courseName: String
    public var credit: Double?
    public var score: Double?
    public var teacherName: String
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

struct ScorePage: Decodable, Sendable {
    var items: [Score]
}

public struct UsualScoreItem: Codable, Hashable, Sendable {
    public var name: String
    public var ratio: String
    public var score: String

    public init(name: String, ratio: String, score: String) {
        self.name = name
        self.ratio = ratio
        self.score = score
    }

    public var hasRatio: Bool { ratio != "N/A" }
}

public struct ScoreGroup: Equatable, Identifiable, Sendable {
    public var year: Int
    public var term: Int
    public var scores: [Score]
    public var id: String { "\(year)-\(term)" }

    public var title: String {
        "\(year)–\(year + 1) " + (term == 1 ? "秋季" : term == 2 ? "春季" : "小学期")
    }

    private var order: Int { year * 10 + (term == 0 ? 3 : term) }

    public static func group(_ scores: [Score]) -> [ScoreGroup] {
        Dictionary(grouping: scores) { "\($0.year)-\($0.term)" }
            .values.map { ScoreGroup(year: $0[0].year, term: $0[0].term, scores: $0) }
            .sorted { $0.order > $1.order }
    }
}
