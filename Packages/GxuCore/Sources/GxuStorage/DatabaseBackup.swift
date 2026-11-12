import Foundation

public struct DatabaseBackup: Codable, Sendable {
    public let formatVersion: Int
    public let createdAt: Date
    public let files: [String: Data]

    public static func capture(at url: URL = AppDatabase.fileURL) throws -> Data {
        let source = try DatabaseOpenBackup(database: url).preservedDatabase() ?? url
        let files = try readFiles(at: source)
        guard try readFiles(at: source) == files else { throw CocoaError(.fileReadUnknown) }
        let backup = DatabaseBackup(formatVersion: 1, createdAt: .now, files: files)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(backup)
    }

    private static func readFiles(at url: URL) throws -> [String: Data] {
        var files = [url.lastPathComponent: try Data(contentsOf: url)]
        for suffix in DatabaseOpenBackup.sidecarSuffixes {
            let sidecar = URL(fileURLWithPath: url.path + suffix)
            do {
                files[sidecar.lastPathComponent] = try Data(contentsOf: sidecar)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                continue
            }
        }
        return files
    }
}
