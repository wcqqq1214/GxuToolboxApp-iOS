import GxuDesign
import GxuFoundation
import SwiftUI

/// 设置 → 诊断日志：查看本机保存的错误日志，可分享给开发者或清除。日志只在本机，不会自动上传，且已脱敏（见 `ErrorLog.redact`）。
public struct ErrorLogView: View {
    private let log: ErrorLog
    @State private var text = ""
    @State private var confirmsClear = false

    public init() { log = .shared }
    init(log: ErrorLog) { self.log = log }

    public var body: some View {
        ScrollView {
            if text.isEmpty {
                GxuEmptyView("没有错误记录", systemImage: "checkmark.shield", message: "出现网络或登录错误时，会在这里留下一条脱敏的记录，方便反馈问题。")
                    .padding(.top, 80)
            } else {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .navigationTitle("诊断日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !text.isEmpty {
                Menu {
                    ShareLink(item: text) { Label("分享日志", systemImage: "square.and.arrow.up") }
                    Button("清除日志", systemImage: "trash", role: .destructive) { confirmsClear = true }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("清除全部日志？", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("清除", role: .destructive) { log.clear(); text = "" }
        }
        .task { text = log.contents() }
        .refreshable { text = log.contents() }
    }
}
