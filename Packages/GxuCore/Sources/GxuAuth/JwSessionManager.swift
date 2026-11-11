import Foundation
import GxuFoundation
import GxuNetworking

public enum AuthState: Sendable, Equatable { case noAccount, needsRelogin, authenticated }

extension AuthState {
    public var displayText: String {
        switch self {
        case .noAccount: "未登录"
        case .authenticated: "已登录"
        case .needsRelogin: "需要重新登录"
        }
    }

    public var showsLoginForm: Bool { self != .authenticated }
}

private struct JwLoginBody: Encodable, Sendable {
    let username: String
    let password: String
}

public actor JwSessionManager: SessionRenewer {
    private let credentials: any CredentialStore
    private let transport: BackendClient
    nonisolated private let cookies: HTTPCookieStorage
    private var pending: Task<Void, Error>?
    private var epoch = 0
    private var observer: (@Sendable (AuthState) -> Void)?

    public init(credentials: any CredentialStore, transport: BackendClient) {
        self.credentials = credentials
        self.transport = transport
        self.cookies = transport.cookieStorage
    }

    public func setObserver(_ observer: (@Sendable (AuthState) -> Void)?) {
        self.observer = observer
    }

    nonisolated public func hasSessionCookie() -> Bool {
        (cookies.cookies(for: GxuConfig.jwCookieURL) ?? []).contains { $0.name == "JSESSIONID" }
    }

    public func login(username: String, password: String) async throws {
        clearSession()
        let startEpoch = epoch
        let (data, response) = try await transport.rawPost("/jw/login", body: JwLoginBody(username: username, password: password))
        guard startEpoch == epoch else { throw CancellationError() }
        guard (200..<300).contains(response.statusCode) else {
            let message = Self.message(in: data)
            if response.statusCode == 401, Self.isCredentialRejectionMessage(message) {
                throw GxuError.credentialsRejected(.jw, message ?? "")
            }
            if response.statusCode == 401 {
                ErrorLog.shared.record("auth", "教务登录：HTTP 401，但不是账号密码错误（message：\(String((message ?? "").prefix(80)))），按服务暂时不可用处理")
                throw GxuError.http(status: 401, message: "教务登录服务暂时不可用：\(message?.isEmpty == false ? message! : "没有给出原因")。这不是账号密码的问题，请稍后再试。")
            }
            throw GxuError.http(status: response.statusCode, message: message)
        }
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String { result[key] = value }
        }
        let parsed = HTTPCookie.cookies(withResponseHeaderFields: headers, for: transport.baseURL)
        guard let session = parsed.first(where: { $0.name == "JSESSIONID" })?.value,
              let route = parsed.first(where: { $0.name == "route" })?.value else {
            throw GxuError.invalidData("登录失败：未获取到教务会话")
        }
        for (name, value) in [("JSESSIONID", session), ("route", route)] {
            if let host = GxuConfig.jwCookieURL.host,
               let cookie = HTTPCookie(properties: [.name: name, .value: value, .domain: host, .path: "/jwglxt", .secure: "TRUE"]) {
                cookies.setCookie(cookie)
            }
            if let host = transport.baseURL.host,
               let cookie = HTTPCookie(properties: [.name: name, .value: value, .domain: host, .path: "/"]) {
                cookies.setCookie(cookie)
            }
        }
        observer?(.authenticated)
    }

    public func renew(_ system: AuthSystem) async throws {
        guard system == .jw else { throw GxuError.sessionExpired(system) }
        if let pending { return try await pending.value }
        let task = Task<Void, Error> {
            guard let credential = credentials.load(.jw) else { throw GxuError.notLoggedIn(.jw) }
            try await login(username: credential.username, password: credential.password)
        }
        pending = task
        defer { pending = nil }
        do { try await task.value } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let error = error as? GxuError, error.isCredentialRejection { observer?(.needsRelogin) }
            throw error
        }
    }

    public func logout() {
        epoch += 1
        pending?.cancel()
        pending = nil
        clearSession()
    }

    private func clearSession() {
        for url in [GxuConfig.jwCookieURL, transport.baseURL] {
            for cookie in cookies.cookies(for: url) ?? [] where ["JSESSIONID", "route"].contains(cookie.name) {
                cookies.deleteCookie(cookie)
            }
        }
    }

    static func isCredentialRejectionMessage(_ message: String?) -> Bool {
        guard let message, !message.isEmpty else { return false }
        return ["账号或密码", "用户名或密码", "账号密码", "密码错误", "密码不正确", "密码不对", "账号错误", "用户名错误", "账号不存在"]
            .contains { message.contains($0) }
    }

    private static func message(in data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (object["message"] as? String) ?? (object["msg"] as? String)
    }
}
