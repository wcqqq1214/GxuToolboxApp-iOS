import Foundation

enum WebPageFailure: Equatable {
    case loginRequired
    case unexpectedPage
    case http(Int)
    case network(String)

    var title: String {
        self == .loginRequired ? "教务登录已失效" : "无法打开教务课表"
    }

    var message: String {
        switch self {
        case .loginRequired:
            "请重新连接教务系统；如果仍失败，请到账号设置重新登录。个人课表仍可从本地导出。"
        case .unexpectedPage:
            "教务网站未返回课表页面，可能发生了登录跳转。请重试，或在 Safari 中查看。"
        case .http(let status):
            "教务网站返回 HTTP \(status)，请稍后重试。个人课表仍可从本地导出。"
        case .network(let message):
            "网页加载失败：\(message)"
        }
    }

    static func httpStatus(_ status: Int) -> Self? {
        if status == 401 { return .loginRequired }
        return status >= 400 ? .http(status) : nil
    }

    static func completedPage(_ url: URL, expected: URL) -> Self? {
        if url.path.lowercased().contains("login") || url.path.lowercased().contains("sso") { return .loginRequired }
        guard url.scheme == "https", url.host == expected.host, url.path == expected.path else { return .unexpectedPage }
        return nil
    }
}
