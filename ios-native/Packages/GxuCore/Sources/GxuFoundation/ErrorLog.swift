import Foundation

/// 本地错误日志：只存在本机，用户可以在设置里查看、分享给开发者或清除，**不会自动上传**。
/// 写入前统一脱敏：URL 查询参数、密码 / token / Authorization、8 位以上的数字（学号、身份证、手机号等）。
/// 文件超过 `maxBytes` 时滚动成 `errors.1.log`（只保留一份历史），总量有上限。
public final class ErrorLog: @unchecked Sendable {
    public static let shared = ErrorLog(directory: ErrorLog.defaultDirectory)

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("GxuLogs", isDirectory: true)
    }

    private let directory: URL
    private let maxBytes: Int
    private let lock = NSLock()
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f
    }()

    public init(directory: URL, maxBytes: Int = 256 * 1024) {
        self.directory = directory
        self.maxBytes = maxBytes
    }

    var currentFile: URL { directory.appendingPathComponent("errors.log") }
    private var previousFile: URL { directory.appendingPathComponent("errors.1.log") }

    /// 记录一条日志。`category` 例如 "network"、"auth"；`message` 会先脱敏
    public func record(_ category: String, _ message: String) {
        let line = "\(formatter.string(from: Date())) [\(category)] \(Self.redact(message))\n"
        lock.withLock {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                rotateIfNeeded(adding: line.utf8.count)
                if !FileManager.default.fileExists(atPath: currentFile.path) {
                    FileManager.default.createFile(atPath: currentFile.path, contents: nil)
                }
                let handle = try FileHandle(forWritingTo: currentFile)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
            } catch {
                // 写日志失败不能影响正常使用
            }
        }
    }

    /// 记录一个请求失败：只写方法、路径（不含查询参数）和错误种类
    public func recordRequest(method: String, url: URL?, failure: String) {
        record("network", "\(method) \(url?.path ?? "?") → \(failure)")
    }

    /// 全部日志（旧的在前），没有日志时返回空串
    public func contents() -> String {
        lock.withLock {
            [previousFile, currentFile].compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        }
    }

    public func clear() {
        lock.withLock {
            try? FileManager.default.removeItem(at: currentFile)
            try? FileManager.default.removeItem(at: previousFile)
        }
    }

    private func rotateIfNeeded(adding bytes: Int) {
        let size = (try? FileManager.default.attributesOfItem(atPath: currentFile.path)[.size] as? Int) ?? 0
        guard size + bytes > maxBytes else { return }
        try? FileManager.default.removeItem(at: previousFile)
        try? FileManager.default.moveItem(at: currentFile, to: previousFile)
    }

    // MARK: 脱敏

    public static func redact(_ text: String) -> String {
        var result = text
        let rules: [(String, String)] = [
            (#"\?[^\s"'<>]*"#, "?…"),                                                  // URL 查询参数
            (#"(?i)\b(Bearer|Token)\s+[A-Za-z0-9._\-]+"#, "$1 ***"),                    // 必须先于下面的 key 规则，否则 "Authorization: Bearer xxx" 只会遮住 "Bearer"
            (#"(?i)\b(password|passwd|pwd|token|authorization|secret|cookie)\b\s*[=:]\s*[^\s,;&"']+"#, "$1=***"),
            (#"(?i)\bJSESSIONID=[^\s;,]+"#, "JSESSIONID=***"),
            (#"\d{8,}"#, "‹数字›"),                                                     // 学号、身份证、手机号
        ]
        for (pattern, template) in rules {
            result = result.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return result
    }
}
