import Foundation

public enum AuthSystem: String, Codable, Sendable, CaseIterable {
    case jw, unified, attendance, oa

    public var displayName: String {
        switch self {
        case .jw: "教务系统"
        case .unified: "统一身份认证"
        case .attendance: "考勤系统"
        case .oa: "OA 系统"
        }
    }
}

/// 逻辑学期：1 = 秋季（教务 xqm=3），2 = 春季（xqm=12），3 = 小学期（xqm=16）
/// 与后端 GET 接口里的 `term` 参数一致（参考 RN 里的 toLogicalTerm）
public struct AcademicTerm: Hashable, Codable, Sendable, Comparable {
    /// 学年起始年，例如 2025 表示 2025-2026 学年
    public var year: Int
    /// 1 / 2 / 3
    public var term: Int

    public init(year: Int, term: Int) {
        self.year = year
        self.term = term
    }

    /// 教务系统的 xqm：3 / 12 / 16
    public var jwXqm: String {
        switch term {
        case 1: "3"
        case 2: "12"
        default: "16"
        }
    }

    /// 后端 GET 接口（`/jw/schedule/personal`、`/jw/exam`、`/jw/score` 等）只接受逻辑学期 1 / 2；
    /// 小学期（3）会返回 400"不支持的学期参数"，不能用它查询。
    public var isBackendQueryable: Bool { term == 1 || term == 2 }

    /// 例如 "2025-2026 秋季学期"
    public var displayName: String {
        let name: String = switch term {
        case 1: "秋季学期"
        case 2: "春季学期"
        default: "小学期"
        }
        return "\(year)-\(year + 1) \(name)"
    }

    /// 从教务 xqm（"3" / "12" / "16"）还原逻辑学期
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

    /// 给 UI 显示的中文文案
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
        }
    }
}

/// 全局常量。后端已支持 HTTPS（2026-11-06 验证：证书有效，登录 / 取数正常），不再需要后端的 ATS 例外；其余 http 例外见 project.yml。
public enum GxuConfig {
    public static let backendBaseURL = URL(string: "https://api.tool.gxutech.xyz")!
    public static let jwCookieURL = URL(string: "https://jwxt2018.gxu.edu.cn/jwglxt")!
    /// App Group（App 和小组件共享数据）。来自 Info.plist 的 `GxuAppGroupID`（`$(GXU_APP_GROUP)`，默认 `group.com.gxutool.ios`，
    /// 可用构建设置 `GXU_BUNDLE_ID` 改掉）。**nil = 不使用 App Group**：免费个人团队不支持时，`run-device.sh --personal`
    /// 会把它置空，App 和小组件各用自己的容器（互相读不到数据），不会崩溃。没有这个键（例如测试宿主）时用默认值。
    public static var appGroupID: String? {
        resolveAppGroupID(Bundle.main.object(forInfoDictionaryKey: "GxuAppGroupID") as? String)
    }

    public static let defaultAppGroupID = "group.com.gxutool.ios"

    /// 纯函数，便于测试：没有键（nil）→ 默认值；空字符串或没展开的 `$(…)` → nil（不使用）；其余原样返回
    public static func resolveAppGroupID(_ infoValue: String?) -> String? {
        guard let infoValue else { return defaultAppGroupID }
        let trimmed = infoValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.contains("$(") ? nil : trimmed
    }
    /// Keychain access group（App 和小组件共用）。真实 Team ID 签名的真机构建里，Info.plist 的 `GxuKeychainAccessGroup`
    /// （`$(AppIdentifierPrefix)com.gxutool.ios`）会展开成 `TEAMID.com.gxutool.ios`，这里就返回它；
    /// 模拟器和 ad-hoc 签名没有 Team ID 前缀，返回 nil（使用 App 默认分组），不受影响。
    public static var keychainAccessGroup: String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        resolveKeychainAccessGroup(Bundle.main.object(forInfoDictionaryKey: "GxuKeychainAccessGroup") as? String)
        #endif
    }

    /// 纯函数，便于测试：只接受展开后带 Team ID 前缀的值（`TEAMID.com.xxx`）；空值、没展开的 `$(…)`、没有前缀的 `com.xxx` 都返回 nil
    public static func resolveKeychainAccessGroup(_ value: String?) -> String? {
        guard let value, !value.isEmpty, !value.contains("$("), !value.hasPrefix("com."),
              value.range(of: #"^[A-Z0-9]{10}\."#, options: .regularExpression) != nil else { return nil }
        return value
    }
}
