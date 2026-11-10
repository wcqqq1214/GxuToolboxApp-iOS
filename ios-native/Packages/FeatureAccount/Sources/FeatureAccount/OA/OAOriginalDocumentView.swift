import SwiftUI
import WebKit

/// 在隔离的 WebView 中加载 OA 原站模板。令牌只写入 OA 域，关闭页面后随 WebView 会话释放。
struct OAOriginalDocumentView: UIViewRepresentable {
    let fileID: Int
    let token: String
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFailure: onFailure) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.addUserScript(
            WKUserScript(source: Self.script(token: token), injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        let url = URL(string: "https://oa.gxu.edu.cn/#/gxuoa/wenjian/view/\(fileID)")!
        let cookie = HTTPCookie(properties: [
            .originURL: url, .domain: "oa.gxu.edu.cn", .path: "/", .name: "token", .value: token, .secure: "TRUE",
        ])
        Task { @MainActor [weak view] in
            if let cookie { await configuration.websiteDataStore.httpCookieStore.setCookie(cookie) }
            view?.load(URLRequest(url: url))
        }
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onFailure: () -> Void

        init(onFailure: @escaping () -> Void) { self.onFailure = onFailure }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as? URLError)?.code != .cancelled { onFailure() }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as? URLError)?.code != .cancelled { onFailure() }
        }

        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if response.isForMainFrame, let http = response.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                onFailure()
                return .cancel
            }
            return .allow
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            if url.scheme == "https", url.host == "oa.gxu.edu.cn", url.port == nil, action.targetFrame != nil {
                return .allow
            }
            if action.navigationType == .linkActivated, url.scheme == "https" || url.scheme == "http" {
                await UIApplication.shared.open(url)
            }
            return .cancel
        }
    }

    private static func script(token: String) -> String {
        let encoder = JSONEncoder()
        let tokenJSON = String(decoding: try! encoder.encode(token), as: UTF8.self)
        let cssJSON = String(decoding: try! encoder.encode(contentCSS), as: UTF8.self)
        return """
        if (location.origin === "https://oa.gxu.edu.cn") {
            try { localStorage.setItem("admin.net:access-token", JSON.stringify(\(tokenJSON))); } catch (_) {}
            document.addEventListener("DOMContentLoaded", () => {
                const style = document.createElement("style");
                style.textContent = \(cssJSON);
                document.head.appendChild(style);
            }, { once: true });
        }
        """
    }

    // 与 RN 文件查看器使用相同的内容区样式，保留 OA 对正文自身的排版。
    private static let contentCSS = """
    .layout-header,
    .layout-aside,
    .layout-aside-mobile,
    .layout-aside-mobile-mode,
    .layout-columns-aside,
    .layout-navbars-tagsview,
    .layout-navbars-breadcrumb-index,
    .layout-breadcrumb-seting,
    .layout-backtop-header-fixed,
    .wenjian-detail-container .action-bar {
        display: none !important;
    }

    html, body, #app, .layout-container, .layout-columns-warp, .layout-main,
    .layout-main-scroll, .layout-main-scroll .el-scrollbar__wrap,
    .layout-main-scroll .el-scrollbar__view, .layout-parent {
        height: auto !important;
        min-height: 100vh !important;
        overflow: visible !important;
        background: #fff !important;
    }

    .layout-padding, .layout-padding-view, .layout-padding-auto {
        position: static !important;
        height: auto !important;
        padding: 0 !important;
        margin: 0 !important;
        overflow: visible !important;
        border: none !important;
        border-radius: 0 !important;
    }

    .layout-container .layout-main .layout-main-scroll .layout-parent {
        padding: 0 !important;
    }

    .wenjian-detail-page, .wenjian-detail-container {
        width: 100% !important;
        max-width: none !important;
        height: auto !important;
        min-height: 0 !important;
        margin: 0 !important;
        padding: 0 !important;
        overflow: visible !important;
        background: #fff !important;
    }

    .file-body-content, .html-content-wrapper {
        width: 100% !important;
        height: auto !important;
        min-height: 0 !important;
        padding: 0 !important;
        overflow: visible !important;
    }

    .html-content-wrapper .html-content-inner {
        width: 100% !important;
        min-width: 0 !important;
        max-width: 100% !important;
        margin: 0 auto !important;
    }
    """
}
