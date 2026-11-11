import Foundation

public enum AuthSystem: String, Codable, Sendable, CaseIterable {
    case jw, unified, attendance, oa, campusNetwork

    public var displayName: String {
        switch self {
        case .jw: "教务系统"
        case .unified: "统一身份认证"
        case .attendance: "考勤系统"
        case .oa: "OA 系统"
        case .campusNetwork: "校园网自服务"
        }
    }
}

public struct AcademicTerm: Hashable, Codable, Sendable, Comparable {
    public var year: Int
    public var term: Int

    public init(year: Int, term: Int) {
        self.year = year
        self.term = term
    }

    public var jwXqm: String {
        switch term {
        case 1: "3"
        case 2: "12"
        default: "16"
        }
    }

    public var isBackendQueryable: Bool { term == 1 || term == 2 }

    public var displayName: String {
        let name: String = switch term {
        case 1: "秋季学期"
        case 2: "春季学期"
        default: "小学期"
        }
        return "\(year)-\(year + 1) \(name)"
    }

    public init?(year: Int, jwXqm: String) {
        switch jwXqm {
        case "3": self.init(year: year, term: 1)
        case "12": self.init(year: year, term: 2)
        case "16": self.init(year: year, term: 3)
        default: return nil
        }
    }

    public static func < (lhs: AcademicTerm, rhs: AcademicTerm) -> Bool {
        (lhs.year, lhs.term) < (rhs.year, rhs.term)
    }
}

public enum GxuError: Error, Sendable, Equatable {
    case notLoggedIn(AuthSystem)
    case sessionExpired(AuthSystem)
    case network(String)
    case http(status: Int, message: String?)
    case decoding(String)
    case invalidData(String)
    case credentialsRejected(AuthSystem, String)

    public var isCredentialRejection: Bool {
        if case .credentialsRejected = self { return true }
        return false
    }

    public var userMessage: String {
        switch self {
        case .notLoggedIn(let system):
            "尚未登录\(system.displayName)，请先在设置中登录"
        case .sessionExpired(let system):
            "\(system.displayName)登录已过期，请重新登录"
        case .network(let message):
            message.isEmpty ? "网络连接失败，请检查网络后重试" : message
        case .http(let status, let message):
            if let message, !message.isEmpty { message } else { "服务器返回错误（\(status)）" }
        case .decoding:
            "数据解析失败，请稍后重试"
        case .invalidData(let message):
            message.isEmpty ? "数据异常" : message
        case .credentialsRejected(let system, let message):
            message.isEmpty ? "\(system.displayName)的账号或密码被服务器拒绝，请重新登录" : message
        }
    }
}

public enum GxuConfig {
    public static let backendBaseURL = URL(string: "https://api.tool.gxutech.xyz")!
    public static let jwCookieURL = URL(string: "https://jwxt2018.gxu.edu.cn/jwglxt")!
    public static var appGroupID: String? {
        resolveAppGroupID(Bundle.main.object(forInfoDictionaryKey: "GxuAppGroupID") as? String)
    }

    public static let defaultAppGroupID = "group.com.gxutool.ios"

    public static func resolveAppGroupID(_ infoValue: String?) -> String? {
        guard let infoValue else { return defaultAppGroupID }
        let trimmed = infoValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.contains("$(") ? nil : trimmed
    }
    public static var keychainAccessGroup: String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        resolveKeychainAccessGroup(Bundle.main.object(forInfoDictionaryKey: "GxuKeychainAccessGroup") as? String)
        #endif
    }

    public static func resolveKeychainAccessGroup(_ value: String?) -> String? {
        guard let value, !value.isEmpty, !value.contains("$("), !value.hasPrefix("com."),
              value.range(of: #"^[A-Z0-9]{10}\."#, options: .regularExpression) != nil else { return nil }
        return value
    }
}
