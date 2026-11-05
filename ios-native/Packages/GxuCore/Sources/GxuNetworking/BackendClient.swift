import Foundation
import GxuFoundation

/// 禁止自动跟随重定向，这样 302 到登录页可以被识别为会话失效。
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

public final class BackendClient: BackendAPI {
    public let baseURL: URL
    private let session: URLSession
    private let renewer: (any SessionRenewer)?
    private let tokenProvider: (@Sendable (AuthSystem) -> String?)?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// - Parameter tokenProvider: 为非 Cookie 认证的系统（考勤）提供 token；有值时请求头加 `Authorization: Token <token>`
    public init(
        baseURL: URL = GxuConfig.backendBaseURL, session: URLSession,
        renewer: (any SessionRenewer)? = nil, tokenProvider: (@Sendable (AuthSystem) -> String?)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.renewer = renewer
        self.tokenProvider = tokenProvider
    }

    /// 创建一个不跟随重定向、10 秒超时的 session。测试里可以传入带 `URLProtocol` 的 configuration。
    public static func makeSession(configuration: URLSessionConfiguration = .default) -> URLSession {
        configuration.timeoutIntervalForRequest = 10
        return URLSession(configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }

    /// 该 session 使用的 Cookie 存储
    public var cookieStorage: HTTPCookieStorage {
        session.configuration.httpCookieStorage ?? .shared
    }

    // MARK: BackendAPI

    public func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let request = try makeRequest(method: "GET", path: path, query: query, body: nil)
        return try decode(try await send(request, auth: auth), as: type)
    }

    public func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        let data: Data
        do { data = try encoder.encode(body) } catch { throw GxuError.invalidData("请求参数编码失败") }
        let request = try makeRequest(method: "POST", path: path, query: [:], body: data)
        return try decode(try await send(request, auth: auth), as: type)
    }

    /// 不做会话检查和自动重登，返回原始响应。登录流程自己需要读 Set-Cookie，所以单独暴露。
    public func rawPost<Body: Encodable & Sendable>(_ path: String, body: Body) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        do { data = try encoder.encode(body) } catch { throw GxuError.invalidData("请求参数编码失败") }
        let request = try makeRequest(method: "POST", path: path, query: [:], body: data)
        return try await perform(request)
    }

    // MARK: Internals

    private func makeRequest(method: String, path: String, query: [String: String], body: Data?) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw GxuError.invalidData("无效的请求地址")
        }
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw GxuError.invalidData("无效的请求地址") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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

    private func send(_ request: URLRequest, auth: AuthSystem?) async throws -> Data {
        var (data, response) = try await perform(authorized(request, auth))
        if let auth, SessionExpiry.isExpired(response, data: data) {
            guard let renewer else { throw GxuError.sessionExpired(auth) }
            try await renewer.renew(auth)
            (data, response) = try await perform(authorized(request, auth))
            if SessionExpiry.isExpired(response, data: data) { throw GxuError.sessionExpired(auth) }
        }
        guard (200..<300).contains(response.statusCode) else {
            ErrorLog.shared.recordRequest(method: request.httpMethod ?? "GET", url: request.url, failure: "HTTP \(response.statusCode)")
            throw GxuError.http(status: response.statusCode, message: Self.errorMessage(in: data))
        }
        return data
    }

    private func authorized(_ request: URLRequest, _ auth: AuthSystem?) -> URLRequest {
        guard let auth, let token = tokenProvider?(auth) else { return request }
        var request = request
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do { return try decoder.decode(type, from: data) } catch {
            throw GxuError.decoding(String(describing: error))
        }
    }

    private static func errorMessage(in data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (object["message"] as? String) ?? (object["msg"] as? String) ?? (object["error"] as? String)
    }
}

/// 会话失效判定：401、302 到登录页、或者返回的是登录页 HTML。
public enum SessionExpiry {
    public static func isExpired(_ response: HTTPURLResponse, data: Data) -> Bool {
        if response.statusCode == 401 { return true }
        if (300..<400).contains(response.statusCode) {
            let location = response.value(forHTTPHeaderField: "Location")?.lowercased() ?? ""
            return location.contains("login") || location.contains("slogin")
        }
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if contentType.contains("html") {
            let prefix = String(decoding: data.prefix(4096), as: UTF8.self).lowercased()
            return prefix.contains("login_slogin") || prefix.contains("用户登录") || prefix.contains("统一身份认证")
        }
        return false
    }
}
