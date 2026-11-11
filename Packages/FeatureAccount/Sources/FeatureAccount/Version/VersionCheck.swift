import Foundation
import SwiftUI

public struct AppUpdate: Sendable, Equatable, Identifiable {
    public let versionName: String
    public let versionCode: Int
    public let notes: String
    public let url: URL
    public var id: Int { versionCode }
}

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

    public static func newestUpdate(in data: Data, currentBuild: Int) -> AppUpdate? {
        let entries = entries(in: data)
        guard let newest = entries.filter({ $0.versionCode > currentBuild }).max(by: { $0.versionCode < $1.versionCode }),
              let link = newest.ori?["appStore"] ?? newest.ori?["testFlight"], let url = URL(string: link),
              url.scheme == "https" else { return nil }
        return AppUpdate(versionName: newest.versionName, versionCode: newest.versionCode, notes: newest.desc ?? "", url: url)
    }

    private static func entries(in data: Data) -> [Entry] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["ios"] as? [[String: Any]] else { return [] }
        return raw.compactMap { dict -> Entry? in
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? JSONDecoder().decode(Entry.self, from: data)
        }
    }

    public static func check(session: URLSession = .shared) async -> AppUpdate? {
        guard let data = await fetch(session: session) else { return nil }
        return newestUpdate(in: data, currentBuild: currentBuild)
    }

    static func releases() async -> [AppUpdate] {
        guard let data = await fetch(session: .shared) else { return [] }
        var seen: Set<Int> = []
        return entries(in: data).sorted { $0.versionCode > $1.versionCode }.compactMap { entry in
            guard let link = entry.ori?["appStore"] ?? entry.ori?["testFlight"],
                  let url = URL(string: link), url.scheme == "https",
                  seen.insert(entry.versionCode).inserted else { return nil }
            return AppUpdate(versionName: entry.versionName, versionCode: entry.versionCode, notes: entry.desc ?? "", url: url)
        }
    }

    private static func fetch(session: URLSession) async -> Data? {
        var request = URLRequest(url: versionURL.appending(queryItems: [URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970)))]))
        request.timeoutInterval = 15
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
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
    public func promptForUpdates() -> some View { modifier(UpdatePromptModifier()) }
}

public struct AppVersionListView: View {
    @State private var releases: [AppUpdate]?
    public init() {}

    public var body: some View {
        List {
            Section("已安装") {
                LabeledContent("当前版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
            }
            Section("发布记录") {
                if let releases {
                    if releases.isEmpty { Text("暂无 iOS 发布记录").foregroundStyle(.secondary) }
                    ForEach(releases) { release in
                        VStack(alignment: .leading, spacing: 6) {
                            Link(release.versionName, destination: release.url)
                            if !release.notes.isEmpty { Text(release.notes).font(.subheadline) }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("软件版本")
        .task { releases = await VersionCheck.releases() }
    }
}
