import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage
import SwiftUI

public struct AppServices: Sendable {
    public let backend: any BackendAPI
    public let database: AppDatabase
    public let shared: any SharedStore
    /// 只能在 MainActor 上访问
    public let accounts: AccountCenter

    public init(backend: any BackendAPI, database: AppDatabase, shared: any SharedStore, accounts: AccountCenter) {
        self.backend = backend
        self.database = database
        self.shared = shared
        self.accounts = accounts
    }
}

/// 未注入服务时的占位：网络请求一律失败。预览请使用 `GxuTestSupport` 的 `.preview`。
private struct UnconfiguredBackend: BackendAPI {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("服务未配置")
    }
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("服务未配置")
    }
}

extension AppServices {
    public static var unconfigured: AppServices {
        MainActor.assumeIsolated {
            let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
            let store = InMemoryCredentialStore()
            let jw = JwSessionManager(credentials: store, transport: client)
            return AppServices(
                backend: UnconfiguredBackend(),
                database: try! AppDatabase.inMemory(features: []),
                shared: UserDefaultsSharedStore(suiteName: nil),
                accounts: AccountCenter(credentials: store, jw: jw)
            )
        }
    }
}

extension EnvironmentValues {
    @Entry public var services: AppServices = .unconfigured
}
