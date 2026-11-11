import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage

public struct UserProfile: Codable, Sendable, Equatable {
    public var studentId: String
    public var name: String
    public var college: String
    public var major: String
    public var className: String
    public var enrollmentYear: Int
    public var studyYears: Int

    public init(studentId: String, name: String, college: String, major: String, className: String, enrollmentYear: Int, studyYears: Int) {
        self.studentId = studentId
        self.name = name
        self.college = college
        self.major = major
        self.className = className
        self.enrollmentYear = enrollmentYear
        self.studyYears = studyYears
    }

    public var academicYears: [Int] {
        (0..<min(max(studyYears, 1), 12)).map { enrollmentYear &+ $0 }
    }
}

private struct ProfileBody: Encodable, Sendable { let isFull: Bool }

private struct ProfileDTO: Decodable, Sendable {
    let student_id: String
    let name: String?
    let college: String?
    let major: String?
    let class_name: String?
    let grade: IntOrString
    let study_years: IntOrString
}

private struct IntOrString: Decodable, Sendable {
    let value: Int?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let string = try? container.decode(String.self) { value = Int(string.trimmingCharacters(in: .whitespaces)) }
        else { value = nil }
    }
}

public struct ProfileRepository: Sendable {
    private let backend: any BackendAPI
    private let shared: any SharedStore

    public init(backend: any BackendAPI, shared: any SharedStore) {
        self.backend = backend
        self.shared = shared
    }

    static func key(_ studentId: String) -> SharedKey<UserProfile> { SharedKey("profile.\(studentId)") }

    public func cached(studentId: String) -> UserProfile? {
        shared.value(Self.key(studentId))
    }

    @discardableResult
    public func load(studentId: String) async throws -> UserProfile {
        let dto = try await backend.postData("/jw/profile", body: ProfileBody(isFull: false), auth: .jw, as: ProfileDTO.self)
        guard dto.student_id == studentId else { throw GxuError.invalidData("账号已切换，请重试") }
        guard let year = dto.grade.value, let years = dto.study_years.value else {
            throw GxuError.invalidData("用户资料缺少入学年份或学制")
        }
        guard (1900...2200).contains(year), (1...12).contains(years) else {
            throw GxuError.invalidData("用户资料中的入学年份或学制异常")
        }
        let profile = UserProfile(
            studentId: studentId, name: dto.name ?? "", college: dto.college ?? "", major: dto.major ?? "",
            className: dto.class_name ?? "", enrollmentYear: year, studyYears: years
        )
        shared.set(profile, for: Self.key(studentId))
        return profile
    }

    public func profile(studentId: String, refresh: Bool = false) async throws -> UserProfile {
        let cache = cached(studentId: studentId)
        if let cache, !refresh { return cache }
        do { return try await load(studentId: studentId) } catch {
            if let cache { return cache }
            throw error
        }
    }
}
