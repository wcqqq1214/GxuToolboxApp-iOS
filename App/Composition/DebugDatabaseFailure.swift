#if DEBUG
import Foundation

enum DebugDatabaseFailure {
    static var fileURL: URL? {
        guard ProcessInfo.processInfo.arguments.contains("-GxuDatabaseFailure") else { return nil }
        return FileManager.default.temporaryDirectory
            .appending(path: "DatabaseRecoveryDemo", directoryHint: .isDirectory)
            .appending(path: "gxu_tool.sqlite")
    }

    static func prepare() throws {
        guard let fileURL else { return }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try Data("Synthetic damaged database for recovery testing".utf8).write(to: fileURL)
        }
    }
}
#endif
