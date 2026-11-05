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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["Account": username, "Password": password])
        let (data, response) = try await perform(request)
        guard (200..<300).contains(response.statusCode) else {
            throw Self.httpError(response, data)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GxuError.decoding("OA 登录响应无法解析")
        }
        guard (object["code"] as? Int) == 200,
              let result = object["result"] as? [String: Any], let token = result["accessToken"] as? String, !token.isEmpty else {
            let message = object["message"] as? String
            throw GxuError.invalidData(message?.isEmpty == false ? message! : "OA 登录失败，请检查账号和密码")
        }
        tokens.save(token)
        observer?(.authenticated)
    }

    /// 保证有可用 token（没有就用 Keychain 里的账号登录）
    public func ensureToken() async throws {
        if tokens.load() == nil { try await renew() }
    }

    public func clear() {
        tokens.save(nil)
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
        if !query.isEmpty { components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

    /// 下载文件（PDF / DOCX 附件）到临时目录，供 QuickLook 预览
    public func download(_ url: URL) async throws -> URL {
        guard url.scheme == "https", url.host?.hasSuffix("gxu.edu.cn") == true else { throw GxuError.invalidData("不支持的文件地址") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, _) = try await send(request)
        let name = url.lastPathComponent.isEmpty ? "file" : url.lastPathComponent
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("oa-preview", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent(name)
        try data.write(to: target, options: .atomic)
        return target
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
            observer?(.signedOut)
            throw error
        }
    }

    private func authorized(_ request: URLRequest) -> URLRequest {
        var request = request
        if let token = tokens.load() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
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
            throw GxuError.network("网络连接失败，请检查网络后重试")
        }
    }

    /// 403 多半是 OA 只允许校内网络访问
    static func httpError(_ response: HTTPURLResponse, _ data: Data) -> GxuError {
        if response.statusCode == 403 { return .http(status: 403, message: "OA 系统拒绝访问，可能需要连接校园网") }
        let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
        return .http(status: response.statusCode, message: message)
    }
}
