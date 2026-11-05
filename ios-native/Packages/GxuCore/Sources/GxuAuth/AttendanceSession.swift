import Foundation
import GxuFoundation
import GxuNetworking

/// 考勤系统 token 存储。生产环境放 Keychain，测试和预览用内存实现。
public protocol TokenStore: Sendable {
    func load() -> String?
    func save(_ token: String?)
}

/// 复用 Keychain 凭据存储，把 token 放在独立的 service 下（账号字段固定为 "token"）。每个系统一个条目。
public final class KeychainTokenStore: TokenStore {
    private let store: KeychainCredentialStore
    private let system: AuthSystem
    public init(system: AuthSystem = .attendance, accessGroup: String? = GxuConfig.keychainAccessGroup) {
        self.system = system
        store = KeychainCredentialStore(service: "com.gxutool.ios.tokens", accessGroup: accessGroup)
    }
    public func load() -> String? { store.load(system)?.password }
    public func save(_ token: String?) {
        if let token { try? store.save(Credential(username: "token", password: token), for: system) } else { store.delete(system) }
    }
}

public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?
    public init(_ token: String? = nil) { self.token = token }
    public func load() -> String? { lock.withLock { token } }
    public func save(_ token: String?) { lock.withLock { self.token = token } }
}

public struct AttendanceCaptcha: Sendable, Equatable {
    /// `data:image/jpeg;base64,...`
    public let imageDataURL: String
    public let ticket: String?

    /// 解码后的图片数据（UI 里 `UIImage(data:)` 用）
    public var imageData: Data? {
        guard let comma = imageDataURL.firstIndex(of: ",") else { return Data(base64Encoded: imageDataURL) }
        return Data(base64Encoded: String(imageDataURL[imageDataURL.index(after: comma)...]))
    }
}

/// 登录成功后保留的考勤用户信息（考勤课表需要 `userId`）
public struct AttendanceLoginInfo: Codable, Sendable, Equatable {
    public let userId: Int
    public let userNo: String?
    public let userName: String?
    public let currentWeek: Int?
}

private struct AttendanceLoginBody: Encodable, Sendable {
    let username: String
    let password: String
    let captchaCode: String
    let ticket: String?
}

private struct CaptchaPayload: Decodable, Sendable {
    let image: String
    let ticket: String?
}

/// 登录结果外层：`{code: 600, msg, data: {token, userInfo, currentWeek...}}`（code 600 才是成功）
private struct AttendanceLoginResult: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct UserInfo: Decodable, Sendable {
            let userId: Int
            let userNo: String?
            let userName: String?
        }
        let token: String
        let userInfo: UserInfo
        let currentWeek: Int?
    }
    let code: Int
    let msg: String?
    let data: Payload?
}

/// 考勤系统会话：验证码登录（`GET /attendance/captcha`、`POST /attendance/login`），token 走 `Authorization: Token`。
/// 登录需要验证码，所以 token 过期后无法静默重登，只能提示用户重新登录。
public final class AttendanceSession: SessionRenewer, @unchecked Sendable {
    private let transport: any BackendAPI
    private let tokens: any TokenStore
    private let lock = NSLock()
    private var observer: (@Sendable (AuthState) -> Void)?
    private var info: AttendanceLoginInfo?

    private static let infoKey = "attendance.loginInfo"
    private let defaults: UserDefaults

    /// - Parameter transport: 不带 renewer 的后端客户端
    public init(transport: any BackendAPI, tokens: any TokenStore, defaults: UserDefaults = .standard) {
        self.transport = transport
        self.tokens = tokens
        self.defaults = defaults
        info = defaults.data(forKey: Self.infoKey).flatMap { try? JSONDecoder().decode(AttendanceLoginInfo.self, from: $0) }
    }

    public func setObserver(_ observer: (@Sendable (AuthState) -> Void)?) {
        lock.withLock { self.observer = observer }
    }

    /// 给 `BackendClient(tokenProvider:)` 用
    public var token: String? { tokens.load() }
    public var hasToken: Bool { tokens.load() != nil }
    public var loginInfo: AttendanceLoginInfo? { lock.withLock { info } }

    public func captcha() async throws -> AttendanceCaptcha {
        let payload = try await transport.getData("/attendance/captcha", query: ["num": "666"], auth: nil, as: CaptchaPayload.self)
        guard !payload.image.isEmpty else { throw GxuError.invalidData("获取验证码失败") }
        return AttendanceCaptcha(imageDataURL: payload.image, ticket: payload.ticket)
    }

    public func login(username: String, password: String, captcha: String, ticket: String?) async throws {
        let body = AttendanceLoginBody(username: username, password: password, captchaCode: captcha, ticket: ticket)
        let result = try await transport.postData("/attendance/login", body: body, auth: nil, as: AttendanceLoginResult.self)
        guard result.code == 600, let payload = result.data else {
            throw GxuError.invalidData(result.msg?.isEmpty == false ? result.msg! : "登录失败，请检查账号、密码和验证码")
        }
        let newInfo = AttendanceLoginInfo(
            userId: payload.userInfo.userId, userNo: payload.userInfo.userNo,
            userName: payload.userInfo.userName, currentWeek: payload.currentWeek
        )
        tokens.save(payload.token)
        defaults.set(try? JSONEncoder().encode(newInfo), forKey: Self.infoKey)
        let observer = lock.withLock { info = newInfo; return self.observer }
        observer?(.authenticated)
    }

    public func clear() {
        tokens.save(nil)
        defaults.removeObject(forKey: Self.infoKey)
        lock.withLock { info = nil }
    }

    /// 后端返回 401（token 无效）：清掉 token，通知状态变为已登出，由 UI 引导用户重新输入验证码
    public func renew(_ system: AuthSystem) async throws {
        tokens.save(nil)
        let observer = lock.withLock { self.observer }
        observer?(.signedOut)
        throw GxuError.sessionExpired(.attendance)
    }
}

/// 按系统分发的会话续期：教务静默重登，考勤只能让状态变为已登出。
public struct SessionRenewers: SessionRenewer {
    private let jw: any SessionRenewer
    private let attendance: any SessionRenewer
    public init(jw: any SessionRenewer, attendance: any SessionRenewer) {
        self.jw = jw
        self.attendance = attendance
    }
    public func renew(_ system: AuthSystem) async throws {
        switch system {
        case .attendance: try await attendance.renew(system)
        default: try await jw.renew(system)
        }
    }
}
