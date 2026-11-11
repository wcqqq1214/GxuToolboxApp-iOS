import Foundation
import GxuFoundation
@_exported import GRDB

public struct FeatureMigrations: Sendable {
    public let feature: String
    public let register: @Sendable (inout DatabaseMigrator) -> Void

    public init(feature: String, register: @escaping @Sendable (inout DatabaseMigrator) -> Void) {
        self.feature = feature
        self.register = register
    }
}

public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    init(writer: any DatabaseWriter, features: [FeatureMigrations]) throws {
        self.writer = writer
        var migrator = DatabaseMigrator()
        for feature in features { feature.register(&migrator) }
        try migrator.migrate(writer)
    }

    public static func databaseDirectory(appGroupID: String?, fileManager fm: FileManager = .default) -> URL {
        appGroupID.flatMap { fm.containerURL(forSecurityApplicationGroupIdentifier: $0) }
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    public static func open(features: [FeatureMigrations]) throws -> AppDatabase {
        let fm = FileManager.default
        let directory = databaseDirectory(appGroupID: GxuConfig.appGroupID, fileManager: fm)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let pool = try DatabasePool(path: directory.appending(path: "gxu_tool.sqlite").path)
        return try AppDatabase(writer: pool, features: features)
    }

    public static func inMemory(features: [FeatureMigrations]) throws -> AppDatabase {
        try AppDatabase(writer: try DatabaseQueue(), features: features)
    }
}

public struct SharedKey<T>: Sendable {
    public let name: String
    public init(name: String) { self.name = name }
    public init(_ name: String) { self.name = name }
}

public protocol SharedStore: Sendable {
    func value<T: Codable & Sendable>(_ key: SharedKey<T>) -> T?
    func set<T: Codable & Sendable>(_ value: T?, for key: SharedKey<T>)
}

public final class UserDefaultsSharedStore: SharedStore {
    nonisolated(unsafe) private let defaults: UserDefaults

    public init(suiteName: String? = GxuConfig.appGroupID) {
        self.defaults = Self.resolveSuite(suiteName).flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    static func resolveSuite(
        _ suiteName: String?, appGroupID: String? = GxuConfig.appGroupID,
        containerExists: (String) -> Bool = { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
    ) -> String? {
        guard let suiteName else { return nil }
        if suiteName == appGroupID, !containerExists(suiteName) { return nil }
        return suiteName
    }

    public func value<T: Codable & Sendable>(_ key: SharedKey<T>) -> T? {
        guard let data = defaults.data(forKey: key.name) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func set<T: Codable & Sendable>(_ value: T?, for key: SharedKey<T>) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key.name)
            return
        }
        defaults.set(data, forKey: key.name)
    }
}
