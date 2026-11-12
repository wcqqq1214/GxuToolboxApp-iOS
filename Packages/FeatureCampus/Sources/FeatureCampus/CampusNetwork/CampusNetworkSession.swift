import Foundation
import GxuAuth
import GxuFoundation

struct CampusNetworkUsage: Codable, Sendable {
    let account: String
    let period: String
    let used: String
    let free: String?
    let available: String?
    let balance: String?
    let plan: String?
    let updatedAt: Date
}

enum CampusNetworkError: LocalizedError {
    case unavailable, unexpectedPage, accountMismatch, loginFailed, passwordRejected, captchaExpired

    var errorDescription: String? {
        switch self {
        case .unavailable: "无法访问校园网自服务，请连接 GXU-WLAN 后重试。"
        case .unexpectedPage: "校园网自服务返回了无法识别的页面。"
        case .accountMismatch: "查询结果的账号与当前校园网账号不一致。"
        case .loginFailed: "校园网登录未通过，请稍后重试。详情见「设置 → 诊断日志」。"
        case .passwordRejected: "校园网账号或密码错误，请检查后重试。"
        case .captchaExpired: "验证码已失效，请重新刷新。"
        }
    }
}

enum CampusNetworkPage {
    enum CaptchaFeedback {
        case required, notRequired
    }

    static func usage(in html: String, account: String, now: Date = .now) throws -> CampusNetworkUsage {
        let rows = html.matches(#"<label\b[^>]*>(.*?)</label>(.*?)</div>"#)
        let fields = Dictionary(rows.map { row in
            (plain(row[0]).filter { !$0.isWhitespace && $0 != "：" && $0 != ":" }, plain(row[1]))
        }, uniquingKeysWith: { first, _ in first })
        guard let returnedAccount = fields["账号"], let period = fields["计费周期"],
              !period.isEmpty else { throw CampusNetworkError.unexpectedPage }
        guard returnedAccount == account else { throw CampusNetworkError.accountMismatch }

        let metrics = Dictionary(html.matches(#"<dl\b[^>]*>\s*<dt\b[^>]*>(.*?)</dt>\s*<dd\b[^>]*>(.*?)</dd>\s*</dl>"#)
            .map { (plain($0[1]), plain($0[0])) }, uniquingKeysWith: { first, _ in first })
        guard let used = metrics["已用流量"], !used.isEmpty else { throw CampusNetworkError.unexpectedPage }
        let available = metrics["可用流量"]
        return CampusNetworkUsage(account: account, period: period, used: used, free: metrics["免费流量"],
                                  available: available?.hasPrefix("-") == true ? nil : available,
                                  balance: metrics["账户余额"], plan: fields["套餐"], updatedAt: now)
    }

    static func form(in html: String) throws -> (action: String, checkcode: String?) {
        guard let action = html.matches(#"<form\b[^>]*\saction\s*=\s*["']([^"']+)["']"#)
            .first?[0] else { throw CampusNetworkError.unexpectedPage }
        for input in html.matches(#"<input\b((?:[^"'<>]|"[^"]*"|'[^']*')*)>"#) {
            let attributes = input[0].matches(#"\s+([\w:-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>]+)))?"#)
            let fields = Dictionary(attributes.map { ($0[0].lowercased(), $0[1...].joined()) }, uniquingKeysWith: { first, _ in first })
            if fields["name"] == "checkcode", let value = fields["value"], !value.isEmpty {
                return (action, value)
            }
        }
        return (action, nil)
    }

    static func captchaFeedback(in html: String) -> CaptchaFeedback? {
        for message in tips(in: html) {
            let text = plain(message).filter { !$0.isWhitespace }
            if text.range(of: #"(?:无需|不需(?:要)?|不用|不必|不要求|请勿)(?:再(?:次)?|重新)?(?:输入|填写)?验证码|验证码(?:无需|不用|不必)(?:输入|填写)"#, options: .regularExpression) != nil {
                return .notRequired
            }
            if text.range(of: #"(?:请(?:重新)?(?:输入|填写)|(?:需要|必须)(?:输入|填写)?)(?:正确的)?验证码|验证码(?:错误|有误|不正确|无效|(?:已)?过期|不能为空|必填|校验失败)"#, options: .regularExpression) != nil {
                return .required
            }
        }
        return nil
    }

    private static func tips(in html: String) -> [String] {
        html.matches(#"\}\)\s*\(\s*(['"])(.*?)\1\s*\)\s*;"#).map { $0[1] }
    }

    static func loginError(in pages: String...) -> CampusNetworkError {
        let tips = pages.flatMap { Self.tips(in: $0) }
        for tip in tips { ErrorLog.shared.record("auth", "校园网登录未通过，tip：\(tip)") }
        if tips.isEmpty { ErrorLog.shared.record("auth", "校园网登录未通过，服务器未提供 tip") }
        let passwordRejected = tips.contains {
            plain($0).range(of: #"^(?:您输入的|输入的)?(?:账号或|帐号或|用户名或)?密码(?:错误|不正确|有误)\s*(?:[，。；！,;.!]|$)"#, options: .regularExpression) != nil
        }
        return passwordRejected ? .passwordRejected : .loginFailed
    }

    private static func plain(_ html: String) -> String {
        html.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

private extension String {
    func matches(_ pattern: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        return expression.matches(in: self, range: NSRange(startIndex..., in: self)).map { match in
            (1..<match.numberOfRanges).map { index in Range(match.range(at: index), in: self).map { String(self[$0]) } ?? "" }
        }
    }
}

actor CampusNetworkSession {
    enum Result: Sendable {
        case usage(CampusNetworkUsage)
        case captcha(Data, rejected: Bool)
    }

    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    private let base = URL(string: "http://self.gxu.edu.cn")!
    private let session: URLSession
    private var challenge: (action: URL, checkcode: String)?

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.timeoutIntervalForRequest = 12
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
    }

    func refresh(_ credential: Credential) async throws -> Result {
        challenge = nil
        if let usage = try await dashboard(account: credential.username) { return .usage(usage) }

        let initialPage = try await loadLoginPage()
        let initialForm = try loginForm(in: initialPage)
        let response = try await postLogin(credential, action: initialForm.action)
        return try await finishLogin(credential, response: response)
    }

    private func finishLogin(_ credential: Credential, response: String, rejectedCaptcha: Bool = false) async throws -> Result {
        if let usage = try await dashboard(account: credential.username) { return .usage(usage) }

        let feedback = CampusNetworkPage.captchaFeedback(in: response)
        guard feedback != .notRequired else { throw CampusNetworkPage.loginError(in: response) }
        let retryPage = try await loadLoginPage()
        guard (feedback ?? CampusNetworkPage.captchaFeedback(in: retryPage)) == .required else {
            throw CampusNetworkPage.loginError(in: response, retryPage)
        }
        return try await requestCaptcha(in: retryPage, rejected: rejectedCaptcha)
    }

    func renewCaptcha() async throws -> Result {
        guard challenge != nil else { throw CampusNetworkError.captchaExpired }
        return try await requestCaptcha(in: loadLoginPage())
    }

    private func requestCaptcha(in html: String, rejected: Bool = false) async throws -> Result {
        challenge = nil
        let form = try loginForm(in: html)
        guard let checkcode = form.checkcode else { throw CampusNetworkError.unexpectedPage }
        let (image, captchaResponse) = try await request(URLRequest(url: base.appending(path: "login/randomCode")))
        guard captchaResponse.statusCode == 200, !image.isEmpty else { throw CampusNetworkError.unexpectedPage }
        challenge = (form.action, checkcode)
        return .captcha(image, rejected: rejected)
    }

    private func loadLoginPage() async throws -> String {
        let loginPage = base.appending(path: "login/")
        let (data, response) = try await request(URLRequest(url: loginPage))
        guard response.statusCode == 200, let html = String(data: data, encoding: .utf8) else {
            throw CampusNetworkError.unexpectedPage
        }
        return html
    }

    private func loginForm(in html: String) throws -> (action: URL, checkcode: String?) {
        let form = try CampusNetworkPage.form(in: html)
        guard let action = URL(string: form.action, relativeTo: base.appending(path: "login/"))?.absoluteURL,
              action.host == base.host, action.scheme == base.scheme,
              action.port == nil || action.port == 80, action.user == nil, action.password == nil,
              action.path.hasPrefix("/login/") else { throw CampusNetworkError.unexpectedPage }
        return (action, form.checkcode)
    }

    func submit(_ code: String, credential: Credential) async throws -> Result {
        guard let challenge else { throw CampusNetworkError.captchaExpired }
        self.challenge = nil
        let response = try await postLogin(credential, action: challenge.action, captcha: ["code": code, "checkcode": challenge.checkcode])
        return try await finishLogin(credential, response: response, rejectedCaptcha: true)
    }

    private func postLogin(_ credential: Credential, action: URL, captcha: [String: String] = [:]) async throws -> String {
        var post = URLRequest(url: action)
        post.httpMethod = "POST"
        post.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let fields = captcha.merging([
            "account": credential.username, "password": credential.password, "foo": "", "bar": "", "submit": "登录",
        ]) { current, _ in current }
        post.httpBody = Data(QueryString.encode(fields).utf8)
        let (data, response) = try await request(post)
        guard (200..<400).contains(response.statusCode) || [400, 401].contains(response.statusCode) else {
            throw CampusNetworkError.loginFailed
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func dashboard(account: String) async throws -> CampusNetworkUsage? {
        let (data, response) = try await request(URLRequest(url: base.appending(path: "dashboard")))
        if response.statusCode == 401 || ((300..<400).contains(response.statusCode)
            && response.value(forHTTPHeaderField: "Location")?.contains("/login") == true) { return nil }
        guard response.statusCode == 200, let html = String(data: data, encoding: .utf8) else {
            throw CampusNetworkError.unexpectedPage
        }
        if html.contains("/login/randomCode"), html.contains("用户自助服务系统") { return nil }
        return try CampusNetworkPage.usage(in: html, account: account)
    }

    private func request(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw CampusNetworkError.unexpectedPage }
            if http.statusCode == 403 || http.statusCode >= 500 { throw CampusNetworkError.unavailable }
            return (data, http)
        } catch is URLError {
            try Task.checkCancellation()
            throw CampusNetworkError.unavailable
        }
    }
}
