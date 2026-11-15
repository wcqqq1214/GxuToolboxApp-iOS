import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit

struct WebPopup: Identifiable, Hashable {
    let id = UUID()
    let url: URL
}

public struct WebViewScreen: View {
    let url: URL
    let title: String?
    let cookies: [HTTPCookie]
    let allowsHTMLExport: Bool
    let onSessionExpired: (() -> Void)?

    @State private var session: WebSession
    @State private var pageTitle: String?
    @State private var progress = 0.0
    @State private var popup: WebPopup?
    @State private var reloadToken = 0
    @State private var loadedPage: WKWebView?
    @State private var html: HTMLDocument?
    @State private var isExporting = false
    @State private var showsFileExporter = false
    @State private var exportError = false
    @State private var pageError: WebPageFailure?
    @Environment(\.openURL) private var openURL

    public init(url: URL, title: String? = nil, cookies: [HTTPCookie] = [], allowsHTMLExport: Bool = false, onSessionExpired: (() -> Void)? = nil) {
        _session = State(initialValue: WebSession(isolated: allowsHTMLExport))
        self.url = url
        self.title = title
        self.cookies = cookies
        self.onSessionExpired = onSessionExpired
        self.allowsHTMLExport = allowsHTMLExport
    }

    private init(url: URL, cookies: [HTTPCookie], session: WebSession) {
        self.init(url: url, cookies: cookies)
        _session = State(initialValue: session)
    }

    public var body: some View {
        WebContainer(url: url, cookies: cookies, dataStore: session.dataStore, reloadsOriginalURL: allowsHTMLExport, reloadToken: reloadToken, pageTitle: $pageTitle, progress: $progress,
                     onPageLoaded: allowsHTMLExport ? { loadedPage = $0; pageError = nil } : nil,
                     onPageFailure: allowsHTMLExport ? { loadedPage = nil; pageError = $0 } : nil) { popup = WebPopup(url: $0) }
            .overlay(alignment: .top) {
                if pageError == nil, progress < 1 { ProgressView(value: progress).progressViewStyle(.linear) }
            }
            .overlay {
                if let pageError {
                    ContentUnavailableView {
                        Label(pageError.title, systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(pageError.message)
                    } actions: {
                        if pageError == .loginRequired, let onSessionExpired {
                            Button("重新连接教务系统", action: onSessionExpired)
                        } else {
                            Button("重试") { reloadToken += 1 }
                        }
                    }
                    .background(.background)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if allowsHTMLExport {
                    Button(isExporting ? "正在保存…" : "保存课表网页", systemImage: "square.and.arrow.up") {
                        Task { await exportHTML() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(loadedPage == nil || isExporting)
                    .padding(8)
                }
            }
            .fileExporter(isPresented: $showsFileExporter, document: html, contentType: .html, defaultFilename: "export_schedule") {
                if case .failure = $0 { exportError = true }
            }
            .alert("课表导出失败", isPresented: $exportError) { Button("好", role: .cancel) {} }
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
            .navigationDestination(item: $popup) { WebViewScreen(url: $0.url, cookies: [], session: session) }
    }

    private func exportHTML() async {
        guard let page = loadedPage, !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let script = """
            (() => {
                const root = document.documentElement.cloneNode(true);
                root.querySelectorAll('script').forEach(script => script.remove());
                root.querySelectorAll('input[type="password"], input[type="hidden"]').forEach(input => input.remove());
                const base = document.createElement('base');
                base.href = document.baseURI;
                if (!root.querySelector('base')) root.querySelector('head')?.prepend(base);
                return '<!doctype html>\\n' + root.outerHTML;
            })()
            """
            guard let text = try await page.evaluateJavaScript(script) as? String,
                  loadedPage === page, !page.isLoading, !text.isEmpty else {
                exportError = true
                return
            }
            html = HTMLDocument(data: Data(text.utf8))
            showsFileExporter = true
        } catch {
            exportError = true
        }
    }
}

private struct HTMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.html] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct WebContainer: UIViewRepresentable {
    let url: URL
    let cookies: [HTTPCookie]
    let dataStore: WKWebsiteDataStore
    let reloadsOriginalURL: Bool
    let reloadToken: Int
    @Binding var pageTitle: String?
    @Binding var progress: Double
    let onPageLoaded: ((WKWebView?) -> Void)?
    let onPageFailure: ((WebPageFailure) -> Void)?
    let onPopup: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        let webView = WKWebView(frame: .zero, configuration: configuration)
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
            if reloadsOriginalURL || webView.url == nil { webView.load(URLRequest(url: url)) } else { webView.reload() }
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
                webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
                    guard let value = change.newValue else { return }
                    Task { @MainActor in self?.parent.progress = value }
                },
                webView.observe(\.title, options: [.new]) { [weak self] _, change in
                    let value = change.newValue ?? nil
                    Task { @MainActor in self?.parent.pageTitle = value }
                },
            ]
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.onPageLoaded?(nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            if let failure = WebPageFailure.completedPage(url, expected: parent.url) {
                parent.onPageFailure?(failure)
            } else {
                parent.onPageLoaded?(webView)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as? URLError)?.code != .cancelled { parent.onPageFailure?(.network(error.localizedDescription)) }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as? URLError)?.code != .cancelled { parent.onPageFailure?(.network(error.localizedDescription)) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            guard parent.onPageFailure != nil, navigationResponse.isForMainFrame,
                  let response = navigationResponse.response as? HTTPURLResponse,
                  let failure = WebPageFailure.httpStatus(response.statusCode) else { return .allow }
            parent.onPageFailure?(failure)
            return .cancel
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else { return .allow }
            if ["http", "https", "about", "blob", "data", "file"].contains(scheme) { return .allow }
            await UIApplication.shared.open(url)
            return .cancel
        }

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
