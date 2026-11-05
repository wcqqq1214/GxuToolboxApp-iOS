import Foundation
import GxuFoundation
import GxuNetworking

public enum AuthState: Sendable, Equatable { case noAccount, signedOut, authenticated }

private struct JwLoginBody: Encodable, Sendable {
    let username: String
    let password: String
}

/// 教务会话：通过后端 `POST /jw/login` 登录，把 `JSESSIONID` / `route` 写进教务域名和后端域名的 Cookie。
/// 多个请求同时发现会话失效时，只会触发一次重新登录（对应 RN `createAuthCore` 的 pendingAuth）。
public actor JwSessionManager: SessionRenewer {
    private let credentials: any CredentialStore
    private let transport: BackendClient
    nonisolated private let cookies: HTTPCookieStorage
    private var pending: Task<Void, Error>?
    private var observer: (@Sendable (AuthState) -> Void)?

    /// - Parameter transport: 不带 renewer 的后端客户端，避免登录请求自己触发重新登录
    public init(credentials: any CredentialStore, transport: BackendClient) {
        self.credentials = credentials
        self.transport = transport
        self.cookies = transport.cookieStorage
    }

    public func setObserver(_ observer: (@Sendable (AuthState) -> Void)?) {
        self.observer = observer
    }

    /// Cookie 里是否有教务会话（不代表仍然有效）
    nonisolated public func hasSession() -> Bool {
        (cookies.cookies(for: GxuConfig.jwCookieURL) ?? []).contains { $0.name == "JSESSIONID" }
    }

    public func login(username: String, password: String) async throws {
        clearSession()
        let (data, response) = try await transport.rawPost("/jw/login", body: JwLoginBody(username: username, password: password))
        guard (200..<300).contains(response.statusCode) else {
            throw GxuError.http(status: response.statusCode, message: Self.message(in: data))
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
        guard system == .jw else { throw GxuError.invalidData("\(system.displayName)暂未支持") }
        if let pending { return try await pending.value }
        let task = Task<Void, Error> {
            guard let credential = credentials.load(.jw) else { throw GxuError.notLoggedIn(.jw) }
            try await login(username: credential.username, password: credential.password)
        }
        pending = task
        defer { pending = nil }
        do { try await task.value } catch {
            observer?(.signedOut)
            throw error
        }
    }

    public func logout() {
        clearSession()
    }

    private func clearSession() {
        for url in [GxuConfig.jwCookieURL, transport.baseURL] {
            for cookie in cookies.cookies(for: url) ?? [] where ["JSESSIONID", "route"].contains(cookie.name) {
                cookies.deleteCookie(cookie)
            }
        }
    }

    private static func message(in data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (object["message"] as? String) ?? (object["msg"] as? String)
    }
}
