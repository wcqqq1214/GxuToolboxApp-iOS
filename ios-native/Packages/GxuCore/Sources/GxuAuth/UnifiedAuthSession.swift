import Foundation
import GxuFoundation

/// 工程训练中心（xlzxms）登录结果：`token` 放进请求头 `authorization`，`studentCode` 是学生码。
public struct EngTrainingSession: Sendable, Equatable {
    public let studentCode: String
    public let token: String
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

/// 统一身份认证（CA，`ca.gxu.edu.cn:8443/zfca`）会话，以及借它登录的 PEC、xlzxms。
/// 这些系统后端没有代理，所以在 App 内直连：RSA 加密密码 → 取 execution → 表单登录 → 带 `service` 参数拿 ticket 并手动跟随重定向。
/// 对应 RN `src/js/auth/auth.ts`。使用独立的 Cookie 存储（ephemeral），不会和教务 / 后端的 Cookie 混在一起。
public actor UnifiedAuthSession {
    public static let pecService = "http://pec.gxu.edu.cn//caslogin.aspx"
    public static let engTrainingService = "http://xlzxms.gxu.edu.cn/api/security-server/dietc/loginsso/student"
    static let caBase = "https://ca.gxu.edu.cn:8443/zfca"

    private let credentials: any CredentialStore
    private let session: URLSession
    private let cookies: HTTPCookieStorage
    private var pending: Task<Void, Error>?

    /// - Parameter configuration: 测试里可传入带 `URLProtocol` 的配置
    public init(credentials: any CredentialStore, configuration: URLSessionConfiguration = .ephemeral) {
        self.credentials = credentials
        configuration.timeoutIntervalForRequest = 15
        configuration.httpShouldSetCookies = true
        self.session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
        self.cookies = configuration.httpCookieStorage ?? HTTPCookieStorage.shared
    }

    // MARK: 登录

    /// 用账号登录统一认证。失败抛 `GxuError.invalidData`（账号密码错误）或网络错误。
    public func login(username: String, password: String) async throws {
        _ = try await casLogin(username: username, password: password, service: nil)
        guard try await testToken() else { throw GxuError.invalidData("统一认证登录失败，请检查账号和密码") }
    }

    /// 统一认证是否可用（RN `authApi.testToken`：返回 JSON 对象才算登录）
    public func testToken() async throws -> Bool {
        var request = URLRequest(url: URL(string: "http://ca.gxu.edu.cn:81/zfim/application/home/getYyfz.zf")!)
        request.httpMethod = "GET"
        let (data, response) = try await send(request)
        guard (200..<300).contains(response.statusCode) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
    }

    public func logout() async {
        var request = URLRequest(url: URL(string: "\(Self.caBase)/logout?service=http://ca.gxu.edu.cn:81/zfim/logout")!)
        request.httpMethod = "GET"
        _ = try? await follow(request)
        for cookie in cookies.cookies ?? [] { cookies.deleteCookie(cookie) }
    }

    /// 用 Keychain 里的账号登录（合并并发调用）
    public func renew() async throws {
        if let pending { return try await pending.value }
        let task = Task<Void, Error> {
            guard let credential = credentials.load(.unified) else { throw GxuError.notLoggedIn(.unified) }
            try await login(username: credential.username, password: credential.password)
        }
        pending = task
        defer { pending = nil }
        try await task.value
    }

    // MARK: 服务登录（PEC、xlzxms）

    /// 登录到某个服务（CAS `service`），返回最终落地的 URL 和内容。服务自己的 Cookie 留在本会话的 Cookie 存储里，
    /// 之后用 `data(for:)` 发请求即可带上。需要 Keychain 里有统一认证账号。
    @discardableResult
    public func serviceLogin(_ service: String) async throws -> (url: URL, data: Data) {
        guard let credential = credentials.load(.unified) else { throw GxuError.notLoggedIn(.unified) }
        let result = try await casLogin(username: credential.username, password: credential.password, service: service)
        if Self.isLoginPage(result.data) { throw GxuError.invalidData("统一认证账号或密码错误") }
        return result
    }

    /// 物理实验平台（PEC）：登录后，用 `data(for:)` 请求 `https://pec.gxu.edu.cn/LMSmini/...`
    public func loginPEC() async throws {
        try await serviceLogin(Self.pecService)
    }

    /// 工程训练中心：取学生码并换 token（RN `loginEngTraining`）
    public func loginEngTraining() async throws -> EngTrainingSession {
        let landed = try await serviceLogin(Self.engTrainingService)
        guard let studentCode = Self.studentCode(from: landed.url) else {
            throw GxuError.invalidData("未获取到工程训练中心学生码")
        }
        var request = URLRequest(url: URL(string: "http://xlzxms.gxu.edu.cn/api/security-server/dietc/sys/authorizing/loginsso")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": studentCode, "code": "ssocode", "queryParam": "queryParam", "password": "1",
        ])
        let (data, response) = try await send(request)
        guard (200..<300).contains(response.statusCode) else { throw GxuError.http(status: response.statusCode, message: nil) }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let datas = object["datas"] as? [String: Any], let token = datas["token"] as? String, !token.isEmpty else {
            throw GxuError.invalidData("工程训练中心登录失败")
        }
        return EngTrainingSession(studentCode: studentCode, token: token)
    }

    /// 用本会话（含 CA / PEC / xlzxms 的 Cookie）发请求，不自动跟随重定向
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await send(request)
    }

    // MARK: Internals

    private struct PubKey: Decodable { let modulus: String; let exponent: String }

    /// RN `authApi.login`：RSA 加密 → 取 execution → POST 表单 → 手动跟随重定向。`service == nil` 是普通登录。
    private func casLogin(username: String, password: String, service: String?) async throws -> (url: URL, data: Data) {
        // 先清掉旧会话，避免带着别人的 TGC
        for cookie in cookies.cookies ?? [] where cookie.domain.contains("gxu.edu.cn") { cookies.deleteCookie(cookie) }

        let keyRequest = URLRequest(url: URL(string: "\(Self.caBase)/v2/getPubKey")!)
        let (keyData, keyResponse) = try await send(keyRequest)
        guard (200..<300).contains(keyResponse.statusCode), let key = try? JSONDecoder().decode(PubKey.self, from: keyData) else {
            throw GxuError.invalidData("获取统一认证公钥失败")
        }
        let encrypted = try ZfcaRSA.encrypt(password: password, exponentHex: key.exponent, modulusHex: key.modulus)

        let page = try await follow(URLRequest(url: URL(string: "\(Self.caBase)/login")!))
        guard let execution = Self.execution(in: page.data) else { throw GxuError.invalidData("统一认证登录页异常") }

        var components = URLComponents(string: "\(Self.caBase)/login")!
        components.queryItems = [URLQueryItem(name: "service", value: service ?? "")]
        var post = URLRequest(url: components.url!)
        post.httpMethod = "POST"
        post.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        post.httpBody = Self.formBody([
            ("username", username), ("password", encrypted), ("execution", execution), ("_eventId", "submit"),
        ])
        let result = try await follow(post)
        if service == nil, Self.isLoginPage(result.data) { throw GxuError.invalidData("统一认证账号或密码错误") }
        return result
    }

    /// 手动跟随 3xx（最多 10 跳）；POST 遇到重定向后改成 GET。返回最终 URL 和内容。
    private func follow(_ initial: URLRequest) async throws -> (url: URL, data: Data) {
        var request = initial
        for _ in 0..<10 {
            let (data, response) = try await send(request)
            guard (300..<400).contains(response.statusCode),
                  let location = response.value(forHTTPHeaderField: "Location"),
                  let next = URL(string: location, relativeTo: response.url)?.absoluteURL else {
                return (response.url ?? request.url!, data)
            }
            var nextRequest = URLRequest(url: next)
            nextRequest.httpMethod = "GET"
            request = nextRequest
        }
        throw GxuError.network("重定向次数过多")
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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

    // MARK: 解析（纯函数，便于测试）

    static func execution(in html: Data) -> String? {
        let text = String(decoding: html, as: UTF8.self)
        let patterns = [
            #"name="execution"[^>]*?value="([^"]+)""#,
            #"value="([^"]+)"[^>]*?name="execution""#,
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression),
               let match = text[range].range(of: #"value="([^"]+)""#, options: .regularExpression) {
                return String(text[match].dropFirst(7).dropLast(1))
            }
        }
        return nil
    }

    static func isLoginPage(_ data: Data) -> Bool {
        let prefix = String(decoding: data.prefix(20_000), as: UTF8.self)
        return prefix.contains("name=\"execution\"") && prefix.contains("id=\"fm1\"")
    }

    /// 重定向落地 URL 末尾 `=` 之后的部分
    static func studentCode(from url: URL) -> String? {
        let text = url.absoluteString
        guard let index = text.lastIndex(of: "=") else { return nil }
        let code = String(text[text.index(after: index)...])
        return code.isEmpty ? nil : code
    }

    static func formBody(_ fields: [(String, String)]) -> Data {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?/:;@$,")
        return Data(fields.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }.joined(separator: "&").utf8)
    }
}
