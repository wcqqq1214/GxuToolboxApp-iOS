import GxuAuth
import GxuDesign
import QuickLook
import SwiftUI
import WebKit

public struct OAFilesView: View {
    @Environment(\.services) private var services
    private let demo: Bool
    public init() { demo = false }
    init(demo: Bool) { self.demo = demo }
    public var body: some View { Content(model: demo ? OAFilesModel.demo(services: services) : OAFilesModel(services: services)) }

    private struct Content: View {
        @State var model: OAFilesModel
        @State private var searchText = ""
        @State private var showsAccount = false

        var body: some View {
            List {
                ForEach(model.rows) { row in
                    NavigationLink { OAFileDetailView(row: row, demo: model.isDemo) { model.didRead($0) } } label: { Row(row: row) }
                        .task { await model.loadMoreIfNeeded(current: row) }
                }
                if model.isLoading && !model.rows.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
                }
            }
            .overlay { placeholder }
            .navigationTitle("OA 文件")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索文件标题")
            .onSubmit(of: .search) { model.keyword = searchText; Task { await model.reload() } }
            .onChange(of: searchText) { _, text in
                if text.isEmpty, !model.keyword.isEmpty { model.keyword = ""; Task { await model.reload() } }
            }
            .toolbar {
                Menu {
                    Picker("文件类型", selection: $model.typeId) {
                        ForEach(OAFileType.all, id: \.id) { Text($0.label).tag($0.id) }
                    }
                } label: {
                    Label("筛选", systemImage: "line.3.horizontal.decrease")
                }
            }
            .onChange(of: model.typeId) { Task { await model.reload() } }
            .navigationDestination(isPresented: $showsAccount) { JwAccountView(system: .oa) }
            .refreshable { await model.reload() }
            .task { if model.rows.isEmpty && !model.isDemo { await model.reload() } }
        }

        @ViewBuilder private var placeholder: some View {
            if model.rows.isEmpty {
                if !model.hasAccount {
                    GxuEmptyView("还没有登录 OA 账号", systemImage: "doc.text", message: "OA 文件需要登录 OA 账号。",
                                 actionTitle: "去登录 OA 账号") { showsAccount = true }
                } else if model.isLoading {
                    GxuLoadingView("正在加载…")
                } else if let error = model.error {
                    GxuErrorView(error.userMessage) { Task { await model.reload() } }
                } else {
                    GxuEmptyView(model.keyword.isEmpty ? "暂无文件" : "没有找到相关文件", systemImage: "doc.text.magnifyingglass")
                }
            }
        }
    }

    private struct Row: View {
        let row: OAFileRow
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !row.isRead { Circle().fill(.tint).frame(width: 8, height: 8).accessibilityLabel("未读") }
                    if row.isUrgent { Text("急").font(.caption.bold()).foregroundStyle(.red) }
                    Text(row.title).font(.headline).lineLimit(2)
                }
                Text([row.fileNum, row.date].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(.secondary)
                if !row.department.isEmpty || !row.typeName.isEmpty {
                    Text([row.typeName, row.department].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct OAFileDetailView: View {
    @Environment(\.services) private var services
    let row: OAFileRow
    var demo = false
    var onRead: (OAFileReadReceipt) -> Void = { _ in }
    var body: some View { Content(model: demo ? OAFileDetailModel.demo(row: row, services: services) : OAFileDetailModel(row: row, services: services, onRead: onRead)) }

    private struct Content: View {
        @State var model: OAFileDetailModel
        @State private var originalPageFailed = false

        var body: some View {
            Group {
                if let detail = model.detail {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(detail.title.isEmpty ? model.row.title : detail.title).font(.headline)
                            Text([detail.fileNum, detail.date, detail.department].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.footnote).foregroundStyle(.secondary)
                            if let message = model.readError {
                                Text(message).font(.footnote).foregroundStyle(.red)
                                Button("重试同步已读") { Task { await model.recordRead() } }
                                    .disabled(model.isRecordingRead)
                            }
                            if let message = model.previewError { Text(message).font(.footnote).foregroundStyle(.red) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        Divider()
                        if let token = model.viewerToken, !originalPageFailed {
                            OAOriginalDocumentView(fileID: model.row.id, token: token) { originalPageFailed = true }
                                .id(token)
                        } else if let html = detail.html {
                            HTMLView(html: html)
                        } else {
                            GxuEmptyView("没有正文", systemImage: "doc", message: detail.pdfURL != nil || detail.docxURL != nil ? "可以通过右上角预览附件。" : nil)
                        }
                    }
                } else if model.isLoading {
                    GxuLoadingView("正在加载…")
                } else if let error = model.error {
                    GxuErrorView(error.userMessage) { Task { await model.load() } }
                }
            }
            .navigationTitle(model.row.fileNum.isEmpty ? "文件详情" : model.row.fileNum)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let detail = model.detail, detail.pdfURL != nil || detail.docxURL != nil {
                    Menu {
                        if let url = detail.pdfURL { Button("预览 PDF", systemImage: "doc.richtext") { Task { await model.preview(url, preferredExtension: "pdf") } } }
                        if let url = detail.docxURL { Button("预览 DOCX", systemImage: "doc.text") { Task { await model.preview(url, preferredExtension: "docx") } } }
                    } label: {
                        if model.isPreparingPreview { ProgressView() } else { Label("预览附件", systemImage: "paperclip") }
                    }
                }
            }
            .quickLookPreview($model.previewURL)
            .task { await model.load() }
        }
    }
}

struct HTMLView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.loadHTMLString(Self.wrapped(html), baseURL: URL(string: "https://oa.gxu.edu.cn"))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    static func wrapped(_ body: String) -> String { OAHTML.wrap(body) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else { return .allow }
            if url.scheme == "https" || url.scheme == "http" { await UIApplication.shared.open(url) }
            return .cancel
        }
    }
}
