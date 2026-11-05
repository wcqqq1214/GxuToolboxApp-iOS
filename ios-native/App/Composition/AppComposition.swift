import Foundation
import GxuAuth
import GxuNetworking
import GxuStorage

/// 组装生产环境的 AppServices
@MainActor
enum AppComposition {
    static func live() -> AppServices {
        let session = BackendClient.makeSession(configuration: .default)
        let credentials = KeychainCredentialStore()
        // 登录请求走不带 renewer 的 transport，避免登录失败时递归重登
        let jw = JwSessionManager(credentials: credentials, transport: BackendClient(session: session))
        let backend = BackendClient(session: session, renewer: jw)
        let database: AppDatabase
        do {
            database = try AppDatabase.open(features: FeatureRegistry.migrations)
        } catch {
            fatalError("数据库打开失败：\(error)")
        }
        return AppServices(
            backend: backend,
            database: database,
            shared: UserDefaultsSharedStore(),
            accounts: AccountCenter(credentials: credentials, jw: jw)
        )
    }
}
