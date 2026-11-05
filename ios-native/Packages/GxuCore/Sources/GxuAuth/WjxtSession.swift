import Foundation
import GxuFoundation

public struct WjxtPendingFile: Sendable, Equatable, Identifiable {
    /// 三段文字用「-」连接（与 RN 一致）
    public let content: String
    public let id: String
    /// 文件页面的相对链接（带 `id=`），用 WebView 打开时需要本会话的 Cookie
    public let href: String
}

/// 问卷系统 / 旧文件系统（`wjxt.gxu.edu.cn`，GB2312 编码的 ASP.NET 页面）。账号与 OA 共用（用户名是身份证号）。
/// 对应 RN `src/js/wjxt/api.ts`：表单登录 → 取待阅文件页面解析。
public actor WjxtSession {
    static let base = URL(string: "https://wjxt.gxu.edu.cn/")!
    private let credentials: any CredentialStore
    private let session: URLSession
    public nonisolated let cookies: HTTPCookieStorage

    public init(credentials: any CredentialStore, configuration: URLSessionConfiguration = .ephemeral) {
        self.credentials = credentials
        configuration.timeoutIntervalForRequest = 15
        session = URLSession(configuration: configuration)
        cookies = configuration.httpCookieStorage ?? .shared
    }

    /// 当前会话的 Cookie，传给 WebView 容器
    public nonisolated func sessionCookies() -> [HTTPCookie] { cookies.cookies(for: Self.base) ?? [] }

    public func login(username: String, password: String) async throws {
        var request = URLRequest(url: Self.base)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // __VIEWSTATE 等是 RN 里写死的值（登录页的固定字段）
        request.httpBody = Data([
            "__VIEWSTATE=/wEPDwUKMTY5ODE4NTcwM2RkIBnlIHU%2BBoqNJr%2BgDM0LFVpP7SfKuRBHRBLFK%2BXqy3o%3D",
            "__VIEWSTATEGENERATOR=C2EE9ABB", "__SCROLLPOSITIONX=0", "__SCROLLPOSITIONY=0",
            "userIdCard=\(Self.encode(username))", "userPwd=\(Self.encode(password))",
            "loginsubmit=%B5%C7+%C2%BC", "myteip=172.30.135.20--2",
        ].joined(separator: "&").utf8)
        _ = try await send(request)
        let page = try await fetchPending()
        if Self.isLoginFailure(page) { throw GxuError.invalidData("问卷系统登录失败，请检查账号和密码") }
    }

    /// 待阅文件。会话失效（页面带 alert）时用 `.oa` 账号登录一次再取
    public func pendingFiles() async throws -> [WjxtPendingFile] {
        var html = try await fetchPending()
        if Self.isLoginFailure(html) {
            guard let credential = credentials.load(.oa) else { throw GxuError.notLoggedIn(.oa) }
            try await login(username: credential.username, password: credential.password)
            html = try await fetchPending()
        }
        return Self.parsePending(html)
    }

    // MARK: Internals

    private func fetchPending() async throws -> String {
        var request = URLRequest(url: URL(string: "Wjxt_UI/qstwj.aspx", relativeTo: Self.base)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await send(request)
        return Self.decodeGB(data)
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GxuError.network("无效的服务器响应") }
            guard (200..<400).contains(http.statusCode) else { throw GxuError.http(status: http.statusCode, message: nil) }
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

    // MARK: 纯函数（便于测试）

    /// 页面里出现 `alert`（脚本弹窗）就是未登录 / 登录失败（RN 同样的判断）
    static func isLoginFailure(_ html: String) -> Bool { html.contains("alert") }

    static func decodeGB(_ data: Data) -> String {
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        return String(data: data, encoding: encoding) ?? String(decoding: data, as: UTF8.self)
    }

    static func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?/:;@$,")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    /// 取所有非空 `<span>` 文本，每 3 个一组合成一条；`<span><a href="...id=123">` 里取文件 id（对应 RN 的 cheerio 解析）
    static func parsePending(_ html: String) -> [WjxtPendingFile] {
        func matches(_ pattern: String, in text: String) -> [[String]] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
                (0..<match.numberOfRanges).map { Range(match.range(at: $0), in: text).map { String(text[$0]) } ?? "" }
            }
        }
        func stripTags(_ text: String) -> String {
            text.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let spans = matches("<span[^>]*>(.*?)</span>", in: html).map { stripTags($0[1]) }.filter { !$0.isEmpty }
        let links = matches("<span[^>]*>\\s*<a[^>]*href=\"([^\"]*)\"", in: html).map { $0[1] }
        var result: [WjxtPendingFile] = []
        var index = 0
        while index < spans.count {
            let content = spans[index..<min(index + 3, spans.count)].joined(separator: "-")
            let href = index / 3 < links.count ? links[index / 3] : ""
            let id = matches("id=(\\d+)", in: href).first?[1] ?? ""
            result.append(WjxtPendingFile(content: content, id: id, href: href))
            index += 3
        }
        return result
    }
}
