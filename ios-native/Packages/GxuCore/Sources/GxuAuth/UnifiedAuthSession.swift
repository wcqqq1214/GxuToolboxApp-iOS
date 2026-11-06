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
    private var observer: (@Sendable (AuthState) -> Void)?

    /// - Parameter configuration: 测试里可传入带 `URLProtocol` 的配置
    public init(credentials: any CredentialStore, configuration: URLSessionConfiguration = .ephemeral) {
        self.credentials = credentials
        configuration.timeoutIntervalForRequest = 15
        configuration.httpShouldSetCookies = true
        self.session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
        self.cookies = configuration.httpCookieStorage ?? HTTPCookieStorage.shared
    }

    public func setObserver(_ observer: (@Sendable (AuthState) -> Void)?) { self.observer = observer }

    // MARK: 登录

    /// 用账号登录统一认证。失败时按原因抛不同的 `GxuError`（只有服务端明确说账号密码有问题时才说账号密码，
    /// 需要验证码 / 被拒绝访问 / 服务异常 / 页面不对都各说各的）；详细原因写进诊断日志（不含密码、token、Cookie）。
    public func login(username: String, password: String) async throws {
        _ = try await casLogin(username: username, password: password, service: nil)
        // RN 同样登录后再用校验接口确认一次
        guard try await testToken() else {
            throw GxuError.invalidData("统一认证接受了登录，但校验接口没有返回预期内容（可能是校园网限制或服务暂时异常）。详情见「设置 → 诊断日志」。")
        }
    }

    /// 统一认证是否可用（RN `authApi.testToken`：**跟随重定向**后返回 JSON 对象才算登录）。
    /// 已登录时，校验接口会 302 到 CAS 换 ticket 再回来；没登录时会落在 CAS 登录页（HTML）。
    public func testToken() async throws -> Bool {
        var request = URLRequest(url: URL(string: "http://ca.gxu.edu.cn:81/zfim/application/home/getYyfz.zf")!)
        request.httpMethod = "GET"
        let landing = try await follow(request)
        guard (200..<300).contains(landing.status) else {
            Self.log("校验接口", landing, note: "状态码异常")
            return false
        }
        guard (try? JSONSerialization.jsonObject(with: landing.data)) is [String: Any] else {
            Self.log("校验接口", landing, note: Self.isLoginPage(landing.data) ? "落在登录页（没有登录）" : "不是 JSON")
            return false
        }
        return true
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
        return (result.url, result.data)
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
    private func casLogin(username: String, password: String, service: String?) async throws -> Landing {
        // 先清掉旧会话，避免带着别人的 TGC
        for cookie in cookies.cookies ?? [] where cookie.domain.contains("gxu.edu.cn") { cookies.deleteCookie(cookie) }

        let keyRequest = URLRequest(url: URL(string: "\(Self.caBase)/v2/getPubKey")!)
        let (keyData, keyResponse) = try await send(keyRequest)
        guard (200..<300).contains(keyResponse.statusCode), let key = try? JSONDecoder().decode(PubKey.self, from: keyData) else {
            throw GxuError.invalidData("获取统一认证公钥失败")
        }
        let encrypted = try ZfcaRSA.encrypt(password: password, exponentHex: key.exponent, modulusHex: key.modulus)

        let page = try await follow(URLRequest(url: URL(string: "\(Self.caBase)/login")!))
        try Self.ensureReachable(page, step: "登录页")
        guard let execution = Self.execution(in: page.data) else {
            Self.log("登录页", page, note: "没有找到 execution")
            throw GxuError.invalidData("统一认证登录页的格式和预期不一样，暂时无法登录。详情见「设置 → 诊断日志」。")
        }
        // 服务端在多次失败后会要求验证码（登录页上的 authcode）。我们没有办法输入，也不要再提交（继续失败可能被锁定），直接如实说明
        if await kaptchaRequired() {
            Self.log("登录页", page, note: "服务端要求验证码（getKaptchaStatus = true）")
            throw GxuError.invalidData("统一认证现在要求输入验证码（通常是登录失败次数过多触发的）。请先在浏览器打开 https://ca.gxu.edu.cn:8443/zfca/login 登录一次，或稍后再试。")
        }

        var components = URLComponents(string: "\(Self.caBase)/login")!
        components.percentEncodedQuery = QueryString.encode(["service": service ?? ""])   // 和 RN 的 encodeURIComponent 一致
        var post = URLRequest(url: components.url!)
        post.httpMethod = "POST"
        post.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        post.httpBody = Self.formBody([
            ("username", username), ("password", encrypted), ("execution", execution), ("_eventId", "submit"),
        ])
        let result = try await follow(post)
        try Self.ensureReachable(result, step: "提交登录")
        if Self.isLoginPage(result.data) {
            Self.log("提交登录", result, note: "又回到了登录页")
            let error = Self.loginPageError(result.data)
            if error.isCredentialRejection { observer?(.signedOut) }   // 服务端明确拒绝：需要重新登录
            throw error
        }
        observer?(.authenticated)
        return result
    }

    /// 登录页是否要求验证码：`GET v2/getKaptchaStatus` 返回 `true`（页面脚本 `showKaptcha()` 同样靠它决定要不要显示 authcode）
    private func kaptchaRequired() async -> Bool {
        guard let (data, response) = try? await send(URLRequest(url: URL(string: "\(Self.caBase)/v2/getKaptchaStatus")!)),
              (200..<300).contains(response.statusCode) else { return false }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
    }

    /// 手动跟随 3xx（最多 10 跳）；POST 遇到重定向后改成 GET。返回最终 URL、内容和状态码。
    private func follow(_ initial: URLRequest) async throws -> Landing {
        var request = initial
        for _ in 0..<10 {
            let (data, response) = try await send(request)
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
            ErrorLog.shared.recordRequest(method: request.httpMethod ?? "GET", url: request.url, failure: "network error \((error as? URLError)?.code.rawValue ?? 0)")
            throw GxuError.network("网络连接失败，请检查网络后重试")
        }
    }

    // MARK: 失败原因分类和日志

    struct Landing {
        let url: URL
        let data: Data
        let status: Int
    }

    /// 403 / 5xx / 其他异常状态码：不是账号密码的问题，各说各的
    static func ensureReachable(_ landing: Landing, step: String) throws {
        switch landing.status {
        case 200..<400: return
        case 401 where isLoginPage(landing.data): return   // 登录页带 401 也是「回到了登录页」，交给调用方按页面内容判断
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

    /// 登录页上服务端给出的错误文字（`<p id="errormsg">`），没有就返回空串
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

    /// 回到了登录页：按服务端自己说的原因分类。只有服务端明确说账号 / 密码有问题才这么说；没有原因就不冤枉用户。
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

    /// 写诊断日志：步骤、状态码、最终的主机和路径（`ErrorLog` 会去掉查询参数）；不含密码、token、Cookie
    static func log(_ step: String, _ landing: Landing, note: String) {
        let host = landing.url.host ?? "?"
        ErrorLog.shared.record("auth", "统一认证 \(step)：\(note)（HTTP \(landing.status)，\(host)\(landing.url.path)）")
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
