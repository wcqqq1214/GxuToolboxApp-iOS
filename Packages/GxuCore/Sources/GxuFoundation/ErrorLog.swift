import Foundation

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
            }
        }
    }

    public func attempt<T>(_ category: String, _ context: String, _ body: () throws -> T) -> T? {
        do { return try body() } catch {
            record(category, "\(context)：\(error)")
            return nil
        }
    }

    public func attempt<T>(
        _ category: String, _ context: String, isolation: isolated (any Actor)? = #isolation, _ body: () async throws -> T
    ) async -> T? {
        do { return try await body() } catch {
            record(category, "\(context)：\(error)")
            return nil
        }
    }

    public func recordRequest(method: String, url: URL?, failure: String) {
        record("network", "\(method) \(url?.path ?? "?") → \(failure)")
    }

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


    public static func redact(_ text: String) -> String {
        var result = text
        let secretKey = #"[A-Za-z_]*(?:password|passwd|pwd|secret|token)"#
        let rules: [(String, String)] = [
            (#"\?[^\s"'<>]*"#, "?…"),
            (#"(?i)("[A-Za-z_]*(?:password|passwd|pwd|secret|token|authorization|cookie)[A-Za-z_]*"\s*:\s*)"[^"]*""#, #"$1"***""#),
            (#"(?i)\b(Bearer|Token)\s+[A-Za-z0-9._\-]+"#, "$1 ***"),
            (#"(?i)\b(?:set-)?cookie\b["']?\s*[=:：]\s*[^\n]*"#, "Cookie=***"),
            (#"(?i)(\#(secretKey)|authorization|密码|口令|令牌)\s*[:：]\s*[^\n]*"#, "$1=***"),
            (#"(?i)(\#(secretKey)|密码|口令)\s*=\s*[^\s&"']+"#, "$1=***"),
            (#"(?i)\bJSESSIONID=[^\s;,]+"#, "JSESSIONID=***"),
            (#"\d(?:[ -]?\d){7,}"#, "‹数字›"),
        ]
        for (pattern, template) in rules {
            result = result.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return result
    }
}
