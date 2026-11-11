import Foundation
import GxuFoundation

public actor OASession {
    public static let apiBase = "https://oa.gxu.edu.cn/api/gxuoa"
    static let loginURL = URL(string: "https://oa.gxu.edu.cn/api/gxuoaAuth/gxuoa/auth/login")!

    private let credentials: any CredentialStore
    private let tokens: any TokenStore
    private let session: URLSession
    private var renewalTask: Task<Void, Error>?
    private var generation = 0
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
        let generation = self.generation
        var request = URLRequest(url: Self.loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["Account": username, "Password": password])
        let (data, response) = try await perform(request)
        try checkGeneration(generation)
        guard (200..<300).contains(response.statusCode) else {
            throw Self.httpError(response, data)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            ErrorLog.shared.record("auth", "OA 登录：响应不是 JSON（HTTP \(response.statusCode)，\(response.value(forHTTPHeaderField: "Content-Type") ?? "无 Content-Type")，\(response.url?.host ?? "?")）")
            throw GxuError.invalidData("OA 返回了意料之外的内容（不是登录结果），可能需要连接校园网或 VPN，或服务暂时不可用。详情见「设置 → 诊断日志」。")
        }
        let code = object["code"] as? Int
        guard code == 200 else {
            let message = (object["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            ErrorLog.shared.record("auth", "OA 登录被服务端拒绝（code \(code.map(String.init) ?? "?")，type \((object["type"] as? String) ?? "?")，message：\(String(message.prefix(80)))）")
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

    public func ensureToken() async throws {
        if tokens.load() == nil { try await renew() }
    }

    public func documentViewerToken() throws -> String {
        guard let token = tokens.load() else { throw GxuError.sessionExpired(.oa) }
        return token
    }

    public func clear() {
        generation &+= 1
        renewalTask?.cancel()
        renewalTask = nil
        tokens.save(nil)
        let storage = session.configuration.httpCookieStorage
        for cookie in storage?.cookies(for: Self.loginURL) ?? [] where cookie.name == "token" {
            storage?.deleteCookie(cookie)
        }
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let generation = self.generation
        if tokens.load() == nil { try await renew() }
        try checkGeneration(generation)
        var (data, response) = try await perform(authorized(request))
        try checkGeneration(generation)
        if response.statusCode == 401 {
            try await renew()
            try checkGeneration(generation)
            (data, response) = try await perform(authorized(request))
            try checkGeneration(generation)
            if response.statusCode == 401 {
                observer?(.needsRelogin)
                throw GxuError.sessionExpired(.oa)
            }
        }
        guard (200..<300).contains(response.statusCode) else { throw Self.httpError(response, data) }
        return (data, response)
    }

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

    public func download(_ url: URL, preferredExtension: String? = nil) async throws -> URL {
        guard url.scheme == "https", Self.isSchoolHost(url.host) else { throw GxuError.invalidData("不支持的文件地址") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await send(request)
        let name = Self.safeFileName(for: url, contentType: response.value(forHTTPHeaderField: "Content-Type"), preferredExtension: preferredExtension)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("oa-preview", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent(name)
        try data.write(to: target, options: .atomic)
        return target
    }

    static let oaHost = "oa.gxu.edu.cn"

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


    private func checkGeneration(_ generation: Int) throws {
        guard generation == self.generation else { throw CancellationError() }
    }

    private func renew() async throws {
        let generation = self.generation
        if let renewalTask {
            try await renewalTask.value
            return try checkGeneration(generation)
        }
        let task = Task<Void, Error> {
            try checkGeneration(generation)
            guard let credential = credentials.load(.oa) else { throw GxuError.notLoggedIn(.oa) }
            try await login(username: credential.username, password: credential.password)
        }
        renewalTask = task
        defer { if generation == self.generation { renewalTask = nil } }
        do {
            try await task.value
            try checkGeneration(generation)
        } catch {
            try checkGeneration(generation)
            if let error = error as? GxuError, error.isCredentialRejection { observer?(.needsRelogin) }
            throw error
        }
    }

    private func authorized(_ request: URLRequest) -> URLRequest {
        var request = request
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

    static func httpError(_ response: HTTPURLResponse, _ data: Data) -> GxuError {
        ErrorLog.shared.recordRequest(method: "OA", url: response.url, failure: "HTTP \(response.statusCode)")
        if response.statusCode == 403 { return .http(status: 403, message: "OA 系统拒绝访问，可能需要连接校园网或 VPN。") }
        let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
        return .http(status: response.statusCode, message: message)
    }
}
