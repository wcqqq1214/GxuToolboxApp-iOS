import FeatureCampus
import Foundation
import SwiftUI
import GxuAuth
import GxuNetworking
import GxuStorage

/// 组装生产环境的 AppServices
@MainActor
enum AppComposition {
    private static var campusCredentials: KeychainCredentialStore {
        let shared = Bundle.main.object(forInfoDictionaryKey: "GxuKeychainAccessGroup") as? String
        let campus = Bundle.main.object(forInfoDictionaryKey: "GxuCampusKeychainAccessGroup") as? String
        // 只有显式移除共享权限的个人团队构建才使用 App 默认组。
        let accessGroup: String?
        if shared == "", campus == "" {
            accessGroup = nil
        } else if let campus, !campus.isEmpty, campus != shared {
            accessGroup = campus
        } else {
            accessGroup = "invalid.campus-network-access-group"
        }
        return KeychainCredentialStore(service: "com.gxutool.ios.campus-network.credentials", accessGroup: accessGroup)
    }

    static func makeCampusNetworkView() -> some View {
        #if DEBUG
        let credentials: any CredentialStore = DemoMode.isEnabled ? InMemoryCredentialStore() : campusCredentials
        #else
        let credentials = campusCredentials
        #endif
        return CampusFeature.makeCampusNetworkView(credentials: credentials)
    }

    private static func migrateCampusCredentials() {
        #if DEBUG
        guard !DemoMode.isEnabled else { return }
        #endif
        let legacyGroup = Bundle.main.object(forInfoDictionaryKey: "GxuKeychainAccessGroup") as? String
        let legacyCampus = KeychainCredentialStore(accessGroup: legacyGroup.flatMap { $0.isEmpty ? nil : $0 })
        let campus = campusCredentials
        if let legacy = legacyCampus.load(.campusNetwork), campus.load(.campusNetwork) == nil {
            try? campus.save(legacy, for: .campusNetwork)
        }
        // 私有组写入失败时，移除共享副本并由用户重新登录。
        legacyCampus.delete(.campusNetwork)
    }

    static func live() -> AppServices {
        migrateCampusCredentials()
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
        let accounts = AccountCenter(credentials: credentials, jw: jw, attendance: attendance, unified: UnifiedAuthSession(credentials: credentials),
            oa: OASession(credentials: credentials, tokens: KeychainTokenStore(system: .oa)),
            wjxt: WjxtSession(credentials: credentials)
        )
        let tracker = AnalyticsTracker(backend: backend)
        #if !DEBUG
        accounts.onLogin = { [accounts] system in
            guard system == .jw else { return }
            let studentId = accounts.studentId
            Task { await tracker.track("login_jw_success", feature: "login", userId: studentId) }
        }
        #endif
        return AppServices(backend: backend, database: database, shared: UserDefaultsSharedStore(), accounts: accounts)
    }
}
