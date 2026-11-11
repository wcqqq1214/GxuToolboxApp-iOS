import Foundation
import GxuFoundation
import GxuNetworking

public protocol TokenStore: Sendable {
    func load() -> String?
    func save(_ token: String?)
}

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
    public let imageDataURL: String
    public let ticket: String?
    public let text: String?

    public init(imageDataURL: String, ticket: String?, text: String? = nil) {
        self.imageDataURL = imageDataURL
        self.ticket = ticket
        self.text = text
    }

    public var imageData: Data? {
        guard let comma = imageDataURL.firstIndex(of: ",") else { return Data(base64Encoded: imageDataURL) }
        return Data(base64Encoded: String(imageDataURL[imageDataURL.index(after: comma)...]))
    }
}

public struct AttendanceLoginInfo: Codable, Sendable, Equatable {
    public let userId: Int
    public let calendarId: Int?
    public let userNo: String?
    public let userName: String?
    public let currentWeek: Int?

    public init(userId: Int, calendarId: Int? = nil, userNo: String? = nil, userName: String? = nil, currentWeek: Int? = nil) {
        self.userId = userId
        self.calendarId = calendarId
        self.userNo = userNo
        self.userName = userName
        self.currentWeek = currentWeek
    }
}

private struct AttendanceLoginBody: Encodable, Sendable {
    let username: String
    let password: String
    let captchaCode: String
    let ticket: String?
}

private struct CaptchaPayload: Decodable, Sendable {
    let imageUrl: String
    let challengeToken: String?
    let text: String?
}

private struct AttendanceLoginResult: Decodable, Sendable {
    let token: String
    let calendarId: Int?
    let userId: Int
}

public final class AttendanceSession: SessionRenewer, @unchecked Sendable {
    private let transport: any BackendAPI
    private let tokens: any TokenStore
    private let lock = NSLock()
    private var observer: (@Sendable (AuthState) -> Void)?
    private var info: AttendanceLoginInfo?

    private static let infoKey = "attendance.loginInfo"
    private let defaults: UserDefaults

    public init(transport: any BackendAPI, tokens: any TokenStore, defaults: UserDefaults = .standard) {
        self.transport = transport
        self.tokens = tokens
        self.defaults = defaults
        info = defaults.data(forKey: Self.infoKey).flatMap { try? JSONDecoder().decode(AttendanceLoginInfo.self, from: $0) }
    }

    public func setObserver(_ observer: (@Sendable (AuthState) -> Void)?) {
        lock.withLock { self.observer = observer }
    }

    public var token: String? { lock.withLock { tokens.load() } }
    public var hasToken: Bool { token != nil }
    public var loginInfo: AttendanceLoginInfo? { lock.withLock { info } }

    public func captcha() async throws -> AttendanceCaptcha {
        let payload = try await transport.getData("/attendance/v2/captcha", query: [:], auth: nil, as: CaptchaPayload.self)
        guard !payload.imageUrl.isEmpty else { throw GxuError.invalidData("获取验证码失败") }
        return AttendanceCaptcha(imageDataURL: payload.imageUrl, ticket: payload.challengeToken, text: payload.text)
    }

    public func login(username: String, password: String, captcha: String, ticket: String?) async throws {
        let body = AttendanceLoginBody(username: username, password: password, captchaCode: captcha, ticket: ticket)
        let result = try await transport.postData("/attendance/v2/login", body: body, auth: nil, as: AttendanceLoginResult.self)
        guard !result.token.isEmpty else { throw GxuError.invalidData("登录失败，请检查账号、密码和验证码") }
        let newInfo = AttendanceLoginInfo(userId: result.userId, calendarId: result.calendarId)
        let observer = lock.withLock {
            tokens.save(result.token)
            defaults.set(try? JSONEncoder().encode(newInfo), forKey: Self.infoKey)
            info = newInfo
            return self.observer
        }
        observer?(.authenticated)
    }

    public func clear() {
        lock.withLock {
            tokens.save(nil)
            defaults.removeObject(forKey: Self.infoKey)
            info = nil
        }
    }

    public func renew(_ system: AuthSystem) async throws {
        try await renew(system, rejectedToken: token)
    }

    public func renew(_ system: AuthSystem, rejectedToken: String?) async throws {
        let observer = try lock.withLock {
            guard tokens.load() == rejectedToken else { throw CancellationError() }
            tokens.save(nil)
            return self.observer
        }
        observer?(.needsRelogin)
        throw GxuError.sessionExpired(.attendance)
    }
}

public struct SessionRenewers: SessionRenewer {
    private let jw: any SessionRenewer
    private let attendance: any SessionRenewer
    public init(jw: any SessionRenewer, attendance: any SessionRenewer) {
        self.jw = jw
        self.attendance = attendance
    }
    public func renew(_ system: AuthSystem) async throws {
        try await renewer(for: system).renew(system)
    }

    public func renew(_ system: AuthSystem, rejectedToken: String?) async throws {
        try await renewer(for: system).renew(system, rejectedToken: rejectedToken)
    }

    private func renewer(for system: AuthSystem) -> any SessionRenewer {
        system == .attendance ? attendance : jw
    }
}
