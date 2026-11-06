import Foundation
import GxuFoundation
import GxuNetworking

/// 账号状态。**首页和详情页都只看这一个值**，文案统一用 `displayText`。
/// - `noAccount`：没有保存的账号（从没登录，或用户主动退出）→「未登录」，详情页显示登录表单
/// - `authenticated`：有保存的账号。会话缺失（例如重装后 Cookie 没了）或网络失败都**不改变**状态，下次请求自动重连 →「已登录」
/// - `signedOut`：服务器**明确拒绝**了保存的账号密码（或考勤 token 失效，需要重新输验证码）→「需要重新登录」，详情页显示登录表单并预填账号。
///   （名字沿用旧的，含义是「需要重新登录」，不是用户主动退出——主动退出是 `noAccount`。）
public enum AuthState: Sendable, Equatable { case noAccount, signedOut, authenticated }

extension AuthState {
    public var displayText: String {
        switch self {
        case .noAccount: "未登录"
        case .authenticated: "已登录"
        case .signedOut: "需要重新登录"
        }
    }

    /// 详情页是否显示登录表单（未登录、需要重新登录）；否则显示已登录内容（含退出按钮）
    public var showsLoginForm: Bool { self != .authenticated }
}

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
    /// 每次 `logout()` 加一。登录请求发出时记下它，回来时发现变了说明用户已经退出，丢弃这次登录（不写 Cookie、不通知已登录）
    private var epoch = 0
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
        let startEpoch = epoch
        let (data, response) = try await transport.rawPost("/jw/login", body: JwLoginBody(username: username, password: password))
        guard startEpoch == epoch else { throw CancellationError() }   // 登录期间用户退出了
        guard (200..<300).contains(response.statusCode) else {
            let message = Self.message(in: data)
            // 登录接口返回 401 = 服务器明确说账号或密码不对（实测：401 `账号或密码错误，登录失败`）；其他状态码（5xx、403 等）不是
            if response.statusCode == 401 { throw GxuError.credentialsRejected(.jw, message ?? "") }
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
            throw CancellationError()   // 退出登录导致的取消，不是"会话失效"
        } catch {
            // 只有服务器明确拒绝账号密码才算「需要重新登录」；断网、超时、5xx 等不改变状态，下次请求会再自动重连
            if let error = error as? GxuError, error.isCredentialRejection { observer?(.signedOut) }
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

    private static func message(in data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (object["message"] as? String) ?? (object["msg"] as? String)
    }
}
