import SwiftUI
import UIKit
import WebKit

/// 点击链接 / `window.open` 弹出的新页面，用来推入导航栈
struct WebPopup: Identifiable, Hashable {
    let id = UUID()
    let url: URL
}

/// WebView 容器：`WKWebView` + Cookie 同步 + 弹窗推入新页面。
/// - `cookies`：加载前写入 WebView 的 Cookie（例如统一认证 / 教务的会话 Cookie），为空则不同步。
/// - `window.open` / `target=_blank` 不会新开窗口，而是推入一个新的 `WebViewScreen`（外层需要 NavigationStack）。
public struct WebViewScreen: View {
    let url: URL
    let title: String?
    let cookies: [HTTPCookie]

    @State private var pageTitle: String?
    @State private var progress = 0.0
    @State private var popup: WebPopup?
    @State private var reloadToken = 0
    @Environment(\.openURL) private var openURL

    public init(url: URL, title: String? = nil, cookies: [HTTPCookie] = []) {
        self.url = url
        self.title = title
        self.cookies = cookies
    }

    public var body: some View {
        WebContainer(url: url, cookies: cookies, reloadToken: reloadToken, pageTitle: $pageTitle, progress: $progress) { popup = WebPopup(url: $0) }
            .overlay(alignment: .top) {
                if progress < 1 { ProgressView(value: progress).progressViewStyle(.linear) }
            }
            .navigationTitle(title ?? pageTitle ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Menu {
                    Button("刷新", systemImage: "arrow.clockwise") { reloadToken += 1 }
                    Button("在 Safari 中打开", systemImage: "safari") { openURL(url) }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            }
            .navigationDestination(item: $popup) { WebViewScreen(url: $0.url, cookies: cookies) }
    }
}

private struct WebContainer: UIViewRepresentable {
    let url: URL
    let cookies: [HTTPCookie]
    let reloadToken: Int
    @Binding var pageTitle: String?
    @Binding var progress: Double
    let onPopup: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.observe(webView)
        let request = URLRequest(url: url)
        let store = webView.configuration.websiteDataStore.httpCookieStore
        Task { @MainActor in
            for cookie in cookies { await store.setCookie(cookie) }
            webView.load(request)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            if webView.url == nil { webView.load(URLRequest(url: url)) } else { webView.reload() }
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebContainer
        var lastReloadToken: Int
        private var observations: [NSKeyValueObservation] = []

        init(_ parent: WebContainer) {
            self.parent = parent
            lastReloadToken = parent.reloadToken
        }

        func observe(_ webView: WKWebView) {
            observations = [
                webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                    let value = view.estimatedProgress
                    Task { @MainActor in self?.parent.progress = value }
                },
                webView.observe(\.title, options: [.new]) { [weak self] view, _ in
                    let value = view.title
                    Task { @MainActor in self?.parent.pageTitle = value }
                },
            ]
        }

        // 非 http(s)（tel:、mailto:、itms-apps: 等）交给系统打开
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else { return .allow }
            if ["http", "https", "about", "blob", "data", "file"].contains(scheme) { return .allow }
            await UIApplication.shared.open(url)
            return .cancel
        }

        // window.open / target=_blank：不新开 WebView，把地址推入新页面
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url { parent.onPopup(url) }
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo) async {
            _ = await present(message: message, confirmable: false)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo) async -> Bool {
            await present(message: message, confirmable: true)
        }

        private func present(message: String, confirmable: Bool) async -> Bool {
            guard let presenter = Self.topViewController() else { return false }
            return await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "好", style: .default) { _ in continuation.resume(returning: true) })
                if confirmable {
                    alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in continuation.resume(returning: false) })
                }
                presenter.present(alert, animated: true)
            }
        }

        private static func topViewController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            var top = scene?.keyWindow?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            return top
        }
    }
}
