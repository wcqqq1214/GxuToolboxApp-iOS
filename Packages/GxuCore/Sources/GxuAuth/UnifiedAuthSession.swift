import Foundation
import GxuFoundation
import Synchronization

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

public actor UnifiedAuthSession {
    public static let pecService = "http://pec.gxu.edu.cn//caslogin.aspx"
    public static let engTrainingService = "http://xlzxms.gxu.edu.cn/api/security-server/dietc/loginsso/student"
    static let caBase = "https://ca.gxu.edu.cn:8443/zfca"

    private let credentials: any CredentialStore
    private let configuration: URLSessionConfiguration
    private var session: URLSession
    private var loginTarget: String?
    private var isLoggingIn = false
    private var pending: Task<Void, Error>?
    private let generation = Mutex(UUID())
    private var observer: (@Sendable (AuthState, UUID) -> Void)?

    private var currentGeneration: UUID { generation.withLock { $0 } }

    nonisolated func isCurrent(_ id: UUID) -> Bool { generation.withLock { $0 == id } }

    private func checkGeneration(_ id: UUID) throws {
        guard isCurrent(id), !Task.isCancelled else { throw CancellationError() }
    }

    private func advanceGeneration() -> UUID {
        let id = UUID()
        generation.withLock { $0 = id }
        pending?.cancel()
        pending = nil
        loginTarget = nil
        isLoggingIn = false
        return id
    }

    public init(credentials: any CredentialStore, configuration: URLSessionConfiguration = .ephemeral) {
        self.credentials = credentials
        configuration.timeoutIntervalForRequest = 15
        configuration.httpShouldSetCookies = true
        self.configuration = configuration
        self.session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
    }

    private func replaceSession() -> URLSession {
        let previous = session
        let configuration = configuration.copy() as! URLSessionConfiguration
        configuration.httpCookieStorage = URLSessionConfiguration.ephemeral.httpCookieStorage
        session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
        return previous
    }

    private func savedCredential() throws -> Credential {
        guard !isLoggingIn else { throw CancellationError() }
        guard let credential = credentials.load(.unified) else { throw GxuError.notLoggedIn(.unified) }
        guard loginTarget == nil || loginTarget == credential.username else { throw CancellationError() }
        return credential
    }

    func setObserver(_ observer: (@Sendable (AuthState, UUID) -> Void)?) { self.observer = observer }


    public func login(username: String, password: String) async throws {
        let id = advanceGeneration()
        replaceSession().invalidateAndCancel()
        isLoggingIn = true
        defer { if isCurrent(id) { isLoggingIn = false } }
        try await verifyLogin(username: username, password: password, generation: id)
        try checkGeneration(id)
        loginTarget = username
    }

    private func verifyLogin(username: String, password: String, generation: UUID) async throws {
        _ = try await casLogin(username: username, password: password, service: nil, generation: generation)
        guard try await testToken(generation: generation) else {
            throw GxuError.invalidData("统一认证接受了登录，但校验接口没有返回预期内容（可能是校园网限制或服务暂时异常）。详情见「设置 → 诊断日志」。")
        }
    }

    public func testToken() async throws -> Bool {
        try await testToken(generation: currentGeneration)
    }

    private func testToken(generation: UUID) async throws -> Bool {
        var request = URLRequest(url: URL(string: "http://ca.gxu.edu.cn:81/zfim/application/home/getYyfz.zf")!)
        request.httpMethod = "GET"
        let landing = try await follow(request, generation: generation)
        guard (200..<300).contains(landing.status) else {
            Self.log("校验接口", landing, note: "状态码异常")
            return false
        }
        guard Self.isJSONContainer(landing.data) else {
            Self.log("校验接口", landing, note: Self.isLoginPage(landing.data) ? "落在登录页（没有登录）" : "不是 JSON 对象或数组")
            return false
        }
        return true
    }

    public func logout() async {
        let id = advanceGeneration()
        let previous = replaceSession()
        defer { previous.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "\(Self.caBase)/logout?service=http://ca.gxu.edu.cn:81/zfim/logout")!)
        request.httpMethod = "GET"
        _ = try? await follow(request, generation: id, using: previous)
    }

    public func renew() async throws {
        if let pending { return try await pending.value }
        let id = currentGeneration
        let task = Task<Void, Error> {
            let credential = try savedCredential()
            try await verifyLogin(username: credential.username, password: credential.password, generation: id)
        }
        pending = task
        defer { if isCurrent(id) { pending = nil } }
        try await task.value
    }


    @discardableResult
    public func serviceLogin(_ service: String) async throws -> (url: URL, data: Data) {
        let result = try await serviceLogin(service, username: nil, generation: currentGeneration)
        return (result.url, result.data)
    }

    private func serviceLogin(_ service: String, username: String?, generation: UUID) async throws -> Landing {
        let credential = try savedCredential()
        guard username == nil || credential.username == username else { throw CancellationError() }
        return try await casLogin(username: credential.username, password: credential.password, service: service, generation: generation)
    }

    public func loginPEC() async throws {
        try await serviceLogin(Self.pecService)
    }

    public func pecData(for request: URLRequest, username: String) async throws -> (Data, HTTPURLResponse) {
        let id = currentGeneration
        _ = try await serviceLogin(Self.pecService, username: username, generation: id)
        return try await send(request, generation: id)
    }

    public func loginEngTraining() async throws -> EngTrainingSession {
        try await loginEngTraining(username: nil, generation: currentGeneration)
    }

    public func engTrainingData(for request: URLRequest, username: String) async throws -> (Data, HTTPURLResponse) {
        let id = currentGeneration
        let session = try await loginEngTraining(username: username, generation: id)
        var request = request
        request.setValue(session.token, forHTTPHeaderField: "authorization")
        return try await send(request, generation: id)
    }

    private func loginEngTraining(username: String?, generation: UUID) async throws -> EngTrainingSession {
        let landed = try await serviceLogin(Self.engTrainingService, username: username, generation: generation)
        guard let studentCode = Self.studentCode(from: landed.url) else {
            throw GxuError.invalidData("未获取到工程训练中心学生码")
        }
        var request = URLRequest(url: URL(string: "http://xlzxms.gxu.edu.cn/api/security-server/dietc/sys/authorizing/loginsso")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": studentCode, "code": "ssocode", "queryParam": "queryParam", "password": "1",
        ])
        let (data, response) = try await send(request, generation: generation)
        guard (200..<300).contains(response.statusCode) else { throw GxuError.http(status: response.statusCode, message: nil) }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let datas = object["datas"] as? [String: Any], let token = datas["token"] as? String, !token.isEmpty else {
            throw GxuError.invalidData("工程训练中心登录失败")
        }
        return EngTrainingSession(studentCode: studentCode, token: token)
    }


    private struct PubKey: Decodable { let modulus: String; let exponent: String }

    private func casLogin(username: String, password: String, service: String?, generation: UUID) async throws -> Landing {
        try checkGeneration(generation)
        if let cookies = session.configuration.httpCookieStorage {
            for cookie in cookies.cookies ?? [] where cookie.domain.contains("gxu.edu.cn") { cookies.deleteCookie(cookie) }
        }

        let keyRequest = URLRequest(url: URL(string: "\(Self.caBase)/v2/getPubKey")!)
        let (keyData, keyResponse) = try await send(keyRequest, generation: generation)
        guard (200..<300).contains(keyResponse.statusCode), let key = try? JSONDecoder().decode(PubKey.self, from: keyData) else {
            throw GxuError.invalidData("获取统一认证公钥失败")
        }
        let encrypted = try ZfcaRSA.encrypt(password: password, exponentHex: key.exponent, modulusHex: key.modulus)

        let page = try await follow(URLRequest(url: URL(string: "\(Self.caBase)/login")!), generation: generation)
        try Self.ensureReachable(page, step: "登录页")
        guard let execution = Self.execution(in: page.data) else {
            Self.log("登录页", page, note: "没有找到 execution")
            throw GxuError.invalidData("统一认证登录页的格式和预期不一样，暂时无法登录。详情见「设置 → 诊断日志」。")
        }
        if try await kaptchaRequired(generation: generation) {
            Self.log("登录页", page, note: "服务端要求验证码（getKaptchaStatus = true）")
            throw GxuError.invalidData("统一认证现在要求输入验证码（通常是登录失败次数过多触发的）。请先在浏览器打开 https://ca.gxu.edu.cn:8443/zfca/login 登录一次，或稍后再试。")
        }

        var components = URLComponents(string: "\(Self.caBase)/login")!
        components.percentEncodedQuery = QueryString.encode(["service": service ?? ""])
        var post = URLRequest(url: components.url!)
        post.httpMethod = "POST"
        post.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        post.httpBody = Self.formBody([
            ("username", username), ("password", encrypted), ("execution", execution), ("_eventId", "submit"),
        ])
        let result = try await follow(post, generation: generation)
        try checkGeneration(generation)
        try Self.ensureReachable(result, step: "提交登录")
        if Self.isLoginPage(result.data) {
            Self.log("提交登录", result, note: "又回到了登录页")
            let error = Self.loginPageError(result.data)
            if !isLoggingIn, error.isCredentialRejection { observer?(.signedOut, generation) }
            throw error
        }
        if !isLoggingIn { observer?(.authenticated, generation) }
        return result
    }

    private func kaptchaRequired(generation: UUID) async throws -> Bool {
        let result = try? await send(URLRequest(url: URL(string: "\(Self.caBase)/v2/getKaptchaStatus")!), generation: generation)
        try checkGeneration(generation)
        guard let (data, response) = result,
              (200..<300).contains(response.statusCode) else { return false }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
    }

    private func follow(_ initial: URLRequest, generation: UUID, using transport: URLSession? = nil) async throws -> Landing {
        var request = initial
        for _ in 0..<10 {
            let (data, response) = try await send(request, generation: generation, using: transport)
            guard (300..<400).contains(response.statusCode),
                  let location = response.value(forHTTPHeaderField: "Location"),
                  let next = URL(string: location, relativeTo: response.url)?.absoluteURL else {
                return Landing(url: response.url ?? request.url!, data: data, status: response.statusCode)
            }
            var nextRequest = URLRequest(url: next)
            nextRequest.httpMethod = "GET"
            request = nextRequest
        }
        throw GxuError.network("重定向次数过多")
    }

    private func send(_ request: URLRequest, generation: UUID, using transport: URLSession? = nil) async throws -> (Data, HTTPURLResponse) {
        try checkGeneration(generation)
        do {
            let (data, response) = try await (transport ?? session).data(for: request)
            try checkGeneration(generation)
            guard let http = response as? HTTPURLResponse else { throw GxuError.network("无效的服务器响应") }
            return (data, http)
        } catch let error as GxuError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            try checkGeneration(generation)
            ErrorLog.shared.recordRequest(method: request.httpMethod ?? "GET", url: request.url, failure: "network error \((error as? URLError)?.code.rawValue ?? 0)")
            throw GxuError.network("网络连接失败，请检查网络后重试")
        }
    }


    struct Landing {
        let url: URL
        let data: Data
        let status: Int
    }

    static func ensureReachable(_ landing: Landing, step: String) throws {
        switch landing.status {
        case 200..<400: return
        case 401 where isLoginPage(landing.data): return
        case 403:
            log(step, landing, note: "被拒绝访问")
            throw GxuError.http(status: 403, message: "统一认证拒绝访问，可能需要连接校园网或 VPN。")
        case 500...:
            log(step, landing, note: "服务端错误")
            throw GxuError.http(status: landing.status, message: "统一认证服务暂时不可用（HTTP \(landing.status)），请稍后再试。")
        default:
            log(step, landing, note: "状态码异常")
            throw GxuError.http(status: landing.status, message: "统一认证返回了意料之外的响应（HTTP \(landing.status)）。详情见「设置 → 诊断日志」。")
        }
    }

    static func pageErrorMessage(in html: Data) -> String {
        let text = String(decoding: html.prefix(60_000), as: UTF8.self)
        guard let range = text.range(of: #"(?s)id="errormsg"[^>]*>(.*?)</p>"#, options: [.regularExpression]) else { return "" }
        let fragment = String(text[range])
        guard let open = fragment.firstIndex(of: ">") else { return "" }
        let inner = fragment[fragment.index(after: open)...].replacingOccurrences(of: "</p>", with: "")
        return inner.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines).prefix(80).description
    }

    static func loginPageError(_ html: Data) -> GxuError {
        let message = pageErrorMessage(in: html)
        if message.contains("验证码") {
            return .invalidData("统一认证要求输入验证码（\(message)）。请先在浏览器登录一次，或稍后再试。")
        }
        if message.contains("锁定") || message.contains("冻结") || message.contains("停用") || message.contains("禁用") {
            return .credentialsRejected(.unified, "统一认证提示：\(message)。")
        }
        if !message.isEmpty { return .credentialsRejected(.unified, "统一认证提示：\(message)") }
        return .invalidData("统一认证没有登录成功，登录页也没有说明原因（可能需要验证码，或服务暂时异常）。详情见「设置 → 诊断日志」。")
    }

    static func log(_ step: String, _ landing: Landing, note: String) {
        let host = landing.url.host ?? "?"
        ErrorLog.shared.record("auth", "统一认证 \(step)：\(note)（HTTP \(landing.status)，\(host)\(landing.url.path)）")
    }


    static func isJSONContainer(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return false }
        return object is [String: Any] || object is [Any]
    }

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
