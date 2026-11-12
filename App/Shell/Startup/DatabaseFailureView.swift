import GxuFoundation
import GxuStorage
import SwiftUI
import UniformTypeIdentifiers

struct DatabaseFailureView: View {
    let code: String
    let retry: () async -> Void
    @State private var isPreparingBackup = false
    @State private var isExporting = false
    @State private var document: DatabaseBackupDocument?
    @State private var feedback: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("本地数据暂时无法打开", systemImage: "externaldrive.badge.exclamationmark")
                        .font(.headline)
                    Text("应用会在打开前保留已有数据库的副本。自定义课程、评教模板等本地数据能否完整恢复，需要进一步检查。")
                    Text("可以先解锁设备、检查可用存储空间后重试。若仍无法打开，请导出备份并保留应用，避免卸载造成数据丢失。")
                }
                Section {
                    Button("重试打开", systemImage: "arrow.clockwise") {
                        Task { await retry() }
                    }
                    Button("导出原始数据备份", systemImage: "square.and.arrow.up") {
                        Task { await prepareBackup() }
                    }
                    if isPreparingBackup { ProgressView("正在准备备份") }
                } footer: {
                    Text("备份包含本地课程、成绩等个人数据，仅保存到你信任的位置。导出不会修复数据库，也不会上传到开发者服务器。")
                }
                .disabled(isPreparingBackup || isExporting)
                if let feedback {
                    Section { Text(feedback).accessibilityIdentifier("databaseBackupFeedback") }
                }
                Section("错误代码") {
                    Text(code).font(.footnote).textSelection(.enabled)
                }
            }
            .navigationTitle("本地数据恢复")
            .fileExporter(isPresented: $isExporting, document: document, contentTypes: [.propertyList],
                          defaultFilename: "gxu-database-backup.plist") { result in
                document = nil
                switch result {
                case .success: feedback = "备份已导出。"
                case .failure: feedback = "备份未能导出，原数据库未被删除。请检查保存位置和可用空间后重试。"
                }
            } onCancellation: {
                document = nil
            }
        }
    }

    private func prepareBackup() async {
        isPreparingBackup = true
        feedback = nil
        defer { isPreparingBackup = false }
        do {
            let url = AppComposition.databaseFileURL
            let data = try await Task.detached { try DatabaseBackup.capture(at: url) }.value
            document = DatabaseBackupDocument(data: data)
            isExporting = true
        } catch {
            let failure = error as NSError
            ErrorLog.shared.record("database.backup", "\(failure.domain) (\(failure.code))")
            feedback = "暂时无法读取备份文件。原数据库未被删除，请解锁设备、检查存储空间后重试。"
        }
    }
}
