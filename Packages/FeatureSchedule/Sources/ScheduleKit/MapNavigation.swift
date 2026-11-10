import Foundation

/// 地图跳转（RN `src/features/map`：`mapUrl.ts` + `useMapNavigation.ts`）。
/// RN 是 Android，支持 高德 / 百度；iOS 同样支持这两个，并加上系统自带的 Apple 地图（始终可用）。
/// 这里只放纯逻辑：各地图的链接、“解析不到 / 没有地图应用 / 直接打开 / 让用户选”的决定。楼名解析（要读校园地点数据）在 FeatureCampus。
public enum MapApp: String, Sendable, Hashable, CaseIterable {
    case apple, amap, baidu

    public var label: String {
        switch self {
        case .apple: "Apple 地图"
        case .amap: "高德地图"
        case .baidu: "百度地图"
        }
    }

    /// RN `SOURCE_APPLICATION`
    static let sourceApplication = "gxujwt"

    /// RN `buildMapUrl`：关键词先去掉首尾空白，参数逐个 percent-encode。高德用 iOS 的 `iosamap://poi`（RN 的 `androidamap` 只在 Android 有效）
    public func url(keyword: String) -> URL? {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .apple:
            return Self.build("https://maps.apple.com/", [("q", trimmed)])
        case .amap:
            return Self.build("iosamap://poi", [("sourceApplication", Self.sourceApplication), ("name", trimmed), ("dev", "0")])
        case .baidu:
            return Self.build("baidumap://map/place/search", [("query", trimmed), ("src", Self.sourceApplication)])
        }
    }

    private static func build(_ base: String, _ items: [(String, String)]) -> URL? {
        // 和 RN 的 `encodeURIComponent` 一致：只保留字母数字和 -_.!~*'()
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
        let query = items.map { key, value in "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }.joined(separator: "&")
        return URL(string: "\(base)?\(query)")
    }

    /// 检测是否安装时用的探测关键词（RN `PROBE_KEYWORD`）
    public static let probeKeyword = "广西大学"
}

/// RN `useMapNavigation.openMap` 的决定：
/// 目标 = 调用方给的关键词，没有就用解析出的楼名全称；解析不到 → 提示“该地点暂不支持自动在地图打开”，不打开；
/// 没有任何地图应用 → 提示；只有一个 → 直接打开；多个 → 让用户选。
public enum MapOpenPlan: Equatable, Sendable {
    case unparsed
    case noApp
    case open(keyword: String, apps: [MapApp])   // apps.count == 1：直接打开；> 1：让用户选

    public static let unparsedMessage = "该地点暂不支持自动在地图打开"
    public static let noAppMessage = "当前未检测到地图应用，请安装后再试"
    public static func openFailedMessage(_ app: MapApp) -> String { "无法打开\(app.label)，请检查是否安装" }

    /// - Parameters:
    ///   - keyword: 调用方直接指定的搜索词（如体育学院的场馆）；空白视为没有
    ///   - parsedFullName: 从地点文案解析出的楼名全称
    ///   - installed: 已安装的地图应用（按显示顺序）
    public static func make(keyword: String?, parsedFullName: String?, installed: [MapApp]) -> MapOpenPlan {
        let direct = keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let target = direct.isEmpty ? (parsedFullName ?? "") : direct
        guard !target.isEmpty else { return .unparsed }
        guard !installed.isEmpty else { return .noApp }
        return .open(keyword: target, apps: installed)
    }
}
