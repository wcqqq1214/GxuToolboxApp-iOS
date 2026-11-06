import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage

/// 教务用户资料（`POST /jw/profile`）。不保存身份证号。
public struct UserProfile: Codable, Sendable, Equatable {
    public var studentId: String
    public var name: String
    public var college: String
    public var major: String
    public var className: String
    /// 入学年份，例如 2022
    public var enrollmentYear: Int
    /// 学制年数，例如 4
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

    /// 在校期间的学年起始年，例如 2022 入学、学制 4 → [2022, 2023, 2024, 2025]
    public var academicYears: [Int] {
        // 后端返回什么数都不能崩：学制限制在 1…12，年份用溢出安全的加法
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

/// 后端把 grade / study_years 返回成字符串，但也兼容数字
private struct IntOrString: Decodable, Sendable {
    let value: Int?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let string = try? container.decode(String.self) { value = Int(string.trimmingCharacters(in: .whitespaces)) }
        else { value = nil }
    }
}

/// 只读、按学号隔离、带本地缓存的用户资料。
/// `cached(studentId:)` 同步返回上次的结果；`load(studentId:)` 请求后端并更新缓存。
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

    /// 请求后端。返回的学号与 `studentId` 不一致时抛错，避免把别人的资料写进当前账号的缓存。
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

    /// 先给缓存；没有缓存或 `refresh` 为 true 时请求后端（请求失败但有缓存时返回缓存）
    public func profile(studentId: String, refresh: Bool = false) async throws -> UserProfile {
        let cache = cached(studentId: studentId)
        if let cache, !refresh { return cache }
        do { return try await load(studentId: studentId) } catch {
            if let cache { return cache }
            throw error
        }
    }
}
