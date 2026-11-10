import Foundation
import GxuFoundation
import Security

public struct Credential: Codable, Sendable, Equatable {
    public var username: String
    public var password: String
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// 账号密码存储。生产环境用 Keychain；测试和预览用内存实现。
public protocol CredentialStore: Sendable {
    func load(_ system: AuthSystem) -> Credential?
    func save(_ credential: Credential, for system: AuthSystem) throws
    func delete(_ system: AuthSystem)
}

public final class KeychainCredentialStore: CredentialStore {
    private let service: String
    private let accessGroup: String?

    public init(service: String = "com.gxutool.ios.credentials", accessGroup: String? = GxuConfig.keychainAccessGroup) {
        self.service = service
        self.accessGroup = accessGroup
    }

    private func query(_ system: AuthSystem) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: system.rawValue,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    public func load(_ system: AuthSystem) -> Credential? {
        var query = query(system)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Credential.self, from: data)
    }

    public func save(_ credential: Credential, for system: AuthSystem) throws {
        let data = try JSONEncoder().encode(credential)
        let status = SecItemUpdate(query(system) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw GxuError.invalidData("无法保存账号（Keychain \(status)）") }
        var add = query(system)
        add[kSecValueData as String] = data
        // 小组件在锁屏后也可能需要读取
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw GxuError.invalidData("无法保存账号（Keychain \(addStatus)）") }
    }

    public func delete(_ system: AuthSystem) {
        SecItemDelete(query(system) as CFDictionary)
    }
}

public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [AuthSystem: Credential]

    public init(_ items: [AuthSystem: Credential] = [:]) { self.items = items }

    public func load(_ system: AuthSystem) -> Credential? { lock.withLock { items[system] } }
    public func save(_ credential: Credential, for system: AuthSystem) throws { lock.withLock { items[system] = credential } }
    public func delete(_ system: AuthSystem) { lock.withLock { items[system] = nil } }
}
