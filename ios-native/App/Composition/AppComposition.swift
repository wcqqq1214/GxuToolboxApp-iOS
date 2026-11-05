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
        let plain = BackendClient(session: session)
        let jw = JwSessionManager(credentials: credentials, transport: plain)
        let attendance = AttendanceSession(transport: plain, tokens: KeychainTokenStore())
        let backend = BackendClient(
            session: session, renewer: SessionRenewers(jw: jw, attendance: attendance),
            tokenProvider: { system in system == .attendance ? attendance.token : nil }
        )
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
            accounts: AccountCenter(credentials: credentials, jw: jw, attendance: attendance)
        )
    }
}
