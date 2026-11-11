import Foundation

public enum MapApp: String, Sendable, Hashable, CaseIterable {
    case apple, amap, baidu

    public var label: String {
        switch self {
        case .apple: "Apple 地图"
        case .amap: "高德地图"
        case .baidu: "百度地图"
        }
    }

    static let sourceApplication = "gxujwt"

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
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
        let query = items.map { key, value in "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }.joined(separator: "&")
        return URL(string: "\(base)?\(query)")
    }

    public static let probeKeyword = "广西大学"
}

public enum MapOpenPlan: Equatable, Sendable {
    case unparsed
    case noApp
    case open(keyword: String, apps: [MapApp])

    public static let unparsedMessage = "该地点暂不支持自动在地图打开"
    public static let noAppMessage = "当前未检测到地图应用，请安装后再试"
    public static func openFailedMessage(_ app: MapApp) -> String { "无法打开\(app.label)，请检查是否安装" }

    public static func make(keyword: String?, parsedFullName: String?, installed: [MapApp]) -> MapOpenPlan {
        let direct = keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let target = direct.isEmpty ? (parsedFullName ?? "") : direct
        guard !target.isEmpty else { return .unparsed }
        guard !installed.isEmpty else { return .noApp }
        return .open(keyword: target, apps: installed)
    }
}
