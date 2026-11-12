import Darwin
import Foundation

struct DatabaseOpenBackup {
    static let sidecarSuffixes = ["-wal", "-shm", "-journal"]

    let database: URL

    private var directory: URL { database.appendingPathExtension("preopen") }
    private var staging: URL { database.appendingPathExtension("preopen-staging") }

    func withLock<T>(_ operation: () throws -> T) throws -> T {
        let lock = database.appendingPathExtension("open-lock")
        let fd = Darwin.open(lock.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { Darwin.close(fd) }
        while flock(fd, LOCK_EX) != 0 {
            let code = errno
            guard code == EINTR else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(code)) }
        }
        return try operation()
    }

    func preservedDatabase() throws -> URL? {
        try exists(directory) ? directory.appending(path: database.lastPathComponent) : nil
    }

    func create() throws {
        let files = try originalFiles()
        guard !files.isEmpty else { return }
        guard files.first == database else { throw CocoaError(.fileReadCorruptFile) }

        let fm = FileManager.default
        try removeStaging()
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? removeStaging() }
        for file in files {
            try fm.copyItem(at: file, to: staging.appending(path: file.lastPathComponent))
        }
        guard try originalFiles() == files,
              files.allSatisfy({ fm.contentsEqual(atPath: $0.path, andPath: staging.appending(path: $0.lastPathComponent).path) })
        else { throw CocoaError(.fileReadUnknown) }
        try fm.moveItem(at: staging, to: directory)
    }

    func finish(archive: Bool) throws {
        guard try preservedDatabase() != nil else { return }
        if archive {
            let archive = database.appendingPathExtension("recovery-" + UUID().uuidString)
            try FileManager.default.moveItem(at: directory, to: archive)
            return
        }
        try removeStaging()
        try FileManager.default.moveItem(at: directory, to: staging)
        try? removeStaging()
    }

    private func originalFiles() throws -> [URL] {
        let sidecars = Self.sidecarSuffixes.map { URL(fileURLWithPath: database.path + $0) }
        return try ([database] + sidecars).filter { try exists($0) }
    }

    private func exists(_ url: URL) throws -> Bool {
        do {
            _ = try FileManager.default.attributesOfItem(atPath: url.path)
            return true
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return false
        }
    }

    private func removeStaging() throws {
        if try exists(staging) { try FileManager.default.removeItem(at: staging) }
    }
}
