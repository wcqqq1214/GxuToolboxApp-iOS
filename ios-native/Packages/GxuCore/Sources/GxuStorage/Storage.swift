import Foundation
import GxuFoundation
@_exported import GRDB

public struct FeatureMigrations: Sendable {
    /// 迁移 ID 的前缀，例如 "schedule"；迁移名必须形如 `schedule.v1.createCourses`
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

    /// 打开 App Group 容器里的 `gxu_tool.sqlite`；容器不可用（例如未签名的模拟器构建）时退回 Application Support。
    public static func open(features: [FeatureMigrations]) throws -> AppDatabase {
        let fm = FileManager.default
        let directory = fm.containerURL(forSecurityApplicationGroupIdentifier: GxuConfig.appGroupID)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let pool = try DatabasePool(path: directory.appending(path: "gxu_tool.sqlite").path)
        return try AppDatabase(writer: pool, features: features)
    }

    /// 测试用
    public static func inMemory(features: [FeatureMigrations]) throws -> AppDatabase {
        try AppDatabase(writer: try DatabaseQueue(), features: features)
    }
}

public struct SharedKey<T>: Sendable {
    public let name: String
    public init(name: String) { self.name = name }
    public init(_ name: String) { self.name = name }
}

/// App Group KV，App 和小组件共用
public protocol SharedStore: Sendable {
    func value<T: Codable & Sendable>(_ key: SharedKey<T>) -> T?
    func set<T: Codable & Sendable>(_ value: T?, for key: SharedKey<T>)
}

public final class UserDefaultsSharedStore: SharedStore {
    // UserDefaults 本身线程安全，只是 SDK 未标注 Sendable
    nonisolated(unsafe) private let defaults: UserDefaults

    public init(suiteName: String? = GxuConfig.appGroupID) {
        self.defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
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
