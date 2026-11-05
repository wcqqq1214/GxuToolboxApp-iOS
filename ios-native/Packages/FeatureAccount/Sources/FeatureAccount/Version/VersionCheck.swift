import Foundation
import SwiftUI

public struct AppUpdate: Sendable, Equatable, Identifiable {
    public let versionName: String
    public let versionCode: Int
    public let notes: String
    /// App Store 或 TestFlight 链接
    public let url: URL
    public var id: Int { versionCode }
}

/// 版本检查：iOS 没有 OTA，只提示并跳转 App Store / TestFlight。
/// 数据来自 RN 同一个 `version.json`，iOS 使用独立的 `ios` 通道（目前文件里还没有，没有该通道就视为没有更新）：
/// `"ios": [{"versionName": "1.0.1", "versionCode": 2, "desc": "...", "ori": {"appStore": "https://apps.apple.com/...", "testFlight": "https://testflight.apple.com/join/..."}}]`
/// `versionCode` 与 App 的 `CFBundleVersion`（构建号）比较。
public enum VersionCheck {
    public static let versionURL = URL(string: "https://file.unde.site/GxuToolApp/version.json")!

    private struct Entry: Decodable {
        let versionName: String
        let versionCode: Int
        let desc: String?
        let ori: [String: String]?
    }

    public static var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    /// 从 version.json 里挑出比 `currentBuild` 新的最高版本；没有 `ios` 通道、没有链接、已是最新都返回 nil
    public static func newestUpdate(in data: Data, currentBuild: Int) -> AppUpdate? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["ios"] as? [[String: Any]] else { return nil }
        let entries = raw.compactMap { dict -> Entry? in
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? JSONDecoder().decode(Entry.self, from: data)
        }
        guard let newest = entries.filter({ $0.versionCode > currentBuild }).max(by: { $0.versionCode < $1.versionCode }),
              let link = newest.ori?["appStore"] ?? newest.ori?["testFlight"], let url = URL(string: link),
              url.scheme == "https" else { return nil }
        return AppUpdate(versionName: newest.versionName, versionCode: newest.versionCode, notes: newest.desc ?? "", url: url)
    }

    /// 联网检查；网络或解析失败返回 nil（检查更新不应该打扰用户）
    public static func check(session: URLSession = .shared) async -> AppUpdate? {
        var request = URLRequest(url: versionURL.appending(queryItems: [URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970)))]))
        request.timeoutInterval = 15
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return newestUpdate(in: data, currentBuild: currentBuild)
    }
}

private struct UpdatePromptModifier: ViewModifier {
    @Environment(\.openURL) private var openURL
    @State private var update: AppUpdate?
    private static let ignoredKey = "version.ignoredCode"

    func body(content: Content) -> some View {
        content
            .task {
                guard let found = await VersionCheck.check(),
                      UserDefaults.standard.integer(forKey: Self.ignoredKey) != found.versionCode else { return }
                update = found
            }
            .alert(item: $update) { update in
                Alert(
                    title: Text("发现新版本 \(update.versionName)"),
                    message: Text(update.notes),
                    primaryButton: .default(Text("前往更新")) { openURL(update.url) },
                    secondaryButton: .cancel(Text("忽略此版本")) {
                        UserDefaults.standard.set(update.versionCode, forKey: Self.ignoredKey)
                    }
                )
            }
    }
}

extension View {
    /// 启动时检查一次更新，有新版本弹窗提示（跳转 App Store / TestFlight）
    public func promptForUpdates() -> some View { modifier(UpdatePromptModifier()) }
}
