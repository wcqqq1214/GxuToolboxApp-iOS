import Foundation
import GxuFoundation

/// OA 文件系统（`oa.gxu.edu.cn`）会话：账号密码登录换 JWT，请求带 `Authorization: Bearer`。
/// 后端没有代理，直连。对应 RN `features/documents/api`：401 时用 Keychain 里的账号重新登录一次再重试；合并并发的重登。
public actor OASession {
    public static let apiBase = "https://oa.gxu.edu.cn/api/gxuoa"
    static let loginURL = URL(string: "https://oa.gxu.edu.cn/api/gxuoaAuth/gxuoa/auth/login")!

    private let credentials: any CredentialStore
    private let tokens: any TokenStore
    private let session: URLSession
    private var pending: Task<Void, Error>?
    private var observer: (@Sendable (AuthState) -> Void)?

    public init(credentials: any CredentialStore, tokens: any TokenStore, configuration: URLSessionConfiguration = .ephemeral) {
        self.credentials = credentials
        self.tokens = tokens
        configuration.timeoutIntervalForRequest = 15
        session = URLSession(configuration: configuration)
    }

    public func setObserver(_ observer: (@Sendable (AuthState) -> Void)?) { self.observer = observer }

    nonisolated public var hasToken: Bool { tokens.load() != nil }

    public func login(username: String, password: String) async throws {
        var request = URLRequest(url: Self.loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["Account": username, "Password": password])
        let (data, response) = try await perform(request)
        guard (200..<300).contains(response.statusCode) else {
            throw Self.httpError(response, data)
        }
        // 不是 JSON（例如校外访问时 WAF 返回的 HTML 页面）：不是账号密码的问题
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            ErrorLog.shared.record("auth", "OA 登录：响应不是 JSON（HTTP \(response.statusCode)，\(response.value(forHTTPHeaderField: "Content-Type") ?? "无 Content-Type")，\(response.url?.host ?? "?")）")
            throw GxuError.invalidData("OA 返回了意料之外的内容（不是登录结果），可能需要连接校园网或 VPN，或服务暂时不可用。详情见「设置 → 诊断日志」。")
        }
        let code = object["code"] as? Int
        guard code == 200 else {
            // 服务端明确拒绝：直接用它给出的文案（例如「[D1000] 账号或密码不正确」）；没有文案就不要替它说是密码错了
            let message = (object["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // 服务端的 message 不含密码，记下来才能查原因（过长截断；ErrorLog 还会再脱敏）
            ErrorLog.shared.record("auth", "OA 登录被服务端拒绝（code \(code.map(String.init) ?? "?")，type \((object["type"] as? String) ?? "?")，message：\(String(message.prefix(80)))）")
            // code 400 / 401 且带文案（例如 `[D1000] 账号或密码不正确`）= 服务端明确拒绝账号密码；其他 code 是服务端的别的问题
            if (code == 400 || code == 401), !message.isEmpty { throw GxuError.credentialsRejected(.oa, message) }
            throw GxuError.invalidData(message.isEmpty ? "OA 登录失败，服务器没有给出原因（code \(code.map(String.init) ?? "?")）。" : message)
        }
        guard let result = object["result"] as? [String: Any], let token = result["accessToken"] as? String, !token.isEmpty else {
            ErrorLog.shared.record("auth", "OA 登录：code 200 但没有 accessToken")
            throw GxuError.invalidData("OA 登录响应里没有访问令牌，可能是服务暂时异常。详情见「设置 → 诊断日志」。")
        }
        tokens.save(token)
        observer?(.authenticated)
    }

    /// 保证有可用 token（没有就用 Keychain 里的账号登录）
    public func ensureToken() async throws {
        if tokens.load() == nil { try await renew() }
    }

    /// OA 原站文件查看器使用的令牌。调用方须将它限制在 OA 的 HTTPS 域。
    public func documentViewerToken() throws -> String {
        guard let token = tokens.load() else { throw GxuError.sessionExpired(.oa) }
        return token
    }

    public func clear() {
        tokens.save(nil)
        let storage = session.configuration.httpCookieStorage
        for cookie in storage?.cookies(for: Self.loginURL) ?? [] where cookie.name == "token" {
            storage?.deleteCookie(cookie)
        }
    }

    /// 带 Bearer 发请求。HTTP 401 时用 Keychain 里的账号重新登录一次再重试；仍然 401 抛 `sessionExpired(.oa)`。
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if tokens.load() == nil { try await renew() }
        var (data, response) = try await perform(authorized(request))
        if response.statusCode == 401 {
            try await renew()
            (data, response) = try await perform(authorized(request))
            if response.statusCode == 401 {
                observer?(.signedOut)
                throw GxuError.sessionExpired(.oa)
            }
        }
        guard (200..<300).contains(response.statusCode) else { throw Self.httpError(response, data) }
        return (data, response)
    }

    /// JSON 请求，返回响应里 `result` 的 JSON 数据（OA 统一响应 `{code, message, result}`，`code != 200` 抛错）
    public func json(_ method: String, path: String, query: [String: String] = [:], body: Data? = nil) async throws -> Data {
        guard var components = URLComponents(string: Self.apiBase + path) else { throw GxuError.invalidData("无效的请求地址") }
        if !query.isEmpty { components.percentEncodedQuery = QueryString.encode(query) }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, _) = try await send(request)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GxuError.decoding("OA 响应无法解析")
        }
        guard (object["code"] as? Int) == 200 else {
            let message = object["message"] as? String
            throw GxuError.invalidData(message?.isEmpty == false ? message! : "OA 请求失败")
        }
        return try JSONSerialization.data(withJSONObject: object["result"] ?? NSNull(), options: [.fragmentsAllowed])
    }

    /// 下载文件（PDF / DOCX 附件）到临时目录，供 QuickLook 预览。
    /// 只允许 `https://gxu.edu.cn` 及其子域；只有发往 `oa.gxu.edu.cn` 的请求才带 Bearer token。
    /// 文件名会被清洗（不能逃出临时目录），没有扩展名时按 Content-Type / `preferredExtension` 补上，QuickLook 靠扩展名选预览类型。
    public func download(_ url: URL, preferredExtension: String? = nil) async throws -> URL {
        guard url.scheme == "https", Self.isSchoolHost(url.host) else { throw GxuError.invalidData("不支持的文件地址") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await send(request)
        let name = Self.safeFileName(for: url, contentType: response.value(forHTTPHeaderField: "Content-Type"), preferredExtension: preferredExtension)
        // 每次下载一个独立目录，同名文件不会互相覆盖
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("oa-preview", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent(name)
        try data.write(to: target, options: .atomic)
        return target
    }

    static let oaHost = "oa.gxu.edu.cn"

    /// `gxu.edu.cn` 本身或真正的子域（`evilgxu.edu.cn` 不算）
    static func isSchoolHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "gxu.edu.cn" || host.hasSuffix(".gxu.edu.cn")
    }

    static func safeFileName(for url: URL, contentType: String?, preferredExtension: String?) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        var base = url.lastPathComponent.replacingOccurrences(of: "\\", with: "/")
        base = String(base.split(separator: "/").last ?? "")
        base = String(base.map { allowed.contains($0) || ($0.unicodeScalars.first.map { $0.value >= 0x4E00 && $0.value <= 0x9FFF } ?? false) ? $0 : "_" })
        while base.hasPrefix(".") { base.removeFirst() }
        base = base.replacingOccurrences(of: "..", with: "_")
        if base.count > 80 { base = String(base.prefix(80)) }
        if base.isEmpty { base = "file" }
        let known: Set<String> = ["pdf", "docx", "doc"]
        let current = (base as NSString).pathExtension.lowercased()
        guard !known.contains(current) else { return base }
        let type = (contentType ?? "").lowercased()
        let ext: String? = type.contains("pdf") ? "pdf"
            : type.contains("wordprocessingml") ? "docx"
            : type.contains("msword") ? "doc"
            : preferredExtension.flatMap { known.contains($0.lowercased()) ? $0.lowercased() : nil }
        return ext.map { "\(base).\($0)" } ?? base
    }

    // MARK: Internals

    private func renew() async throws {
        if let pending { return try await pending.value }
        let task = Task<Void, Error> {
            guard let credential = credentials.load(.oa) else { throw GxuError.notLoggedIn(.oa) }
            try await login(username: credential.username, password: credential.password)
        }
        pending = task
        defer { pending = nil }
        do { try await task.value } catch {
            // 只有服务器明确拒绝账号密码才算「需要重新登录」；网络错误、非 JSON 页面、5xx 不改变状态
            if let error = error as? GxuError, error.isCredentialRejection { observer?(.signedOut) }
            throw error
        }
    }

    private func authorized(_ request: URLRequest) -> URLRequest {
        var request = request
        // 只给 OA 自己的域名带 token，别的校内域名（例如附件放在别处）不带
        if let url = request.url, url.scheme == "https", url.host?.lowercased() == Self.oaHost,
           url.port == nil || url.port == 443, let token = tokens.load() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let cookie = HTTPCookie(properties: [
                .originURL: url, .domain: Self.oaHost, .path: "/", .name: "token", .value: token, .secure: "TRUE",
            ]) {
                session.configuration.httpCookieStorage?.setCookies([cookie], for: url, mainDocumentURL: url)
            }
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GxuError.network("无效的服务器响应") }
            return (data, http)
        } catch let error as GxuError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            ErrorLog.shared.recordRequest(method: request.httpMethod ?? "GET", url: request.url, failure: "network error \((error as? URLError)?.code.rawValue ?? 0)")
            throw GxuError.network("网络连接失败，请检查网络后重试")
        }
    }

    /// 403 多半是 OA 只允许校内网络访问
    static func httpError(_ response: HTTPURLResponse, _ data: Data) -> GxuError {
        ErrorLog.shared.recordRequest(method: "OA", url: response.url, failure: "HTTP \(response.statusCode)")
        if response.statusCode == 403 { return .http(status: 403, message: "OA 系统拒绝访问，可能需要连接校园网或 VPN。") }
        let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
        return .http(status: response.statusCode, message: message)
    }
}
