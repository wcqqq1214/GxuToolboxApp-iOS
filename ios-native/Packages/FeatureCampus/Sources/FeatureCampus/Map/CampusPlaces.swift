import Foundation

/// 校园地点（地图导航列表）。数据由 RN 的 `type/pos.ts` 转换而来（`Resources/campus-places.json`）。
public struct CampusPlace: Decodable, Sendable, Hashable, Identifiable {
    public let type: String
    public let name: String
    /// 用来在地图 App 里搜索的全名
    public let fullName: String
    /// 俗称 / 简称，搜索时也会匹配
    public let aliases: [String]
    /// 教室文案（如 “6A-427”）匹配这个地点的正则；没有则为 nil
    public let pattern: String?

    public var id: String { fullName + name }

    public func matches(room text: String) -> Bool {
        guard let pattern, let regex = try? Regex(pattern) else { return false }
        return text.firstMatch(of: regex) != nil
    }

    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || name.localizedStandardContains(q) || fullName.localizedStandardContains(q)
            || aliases.contains { $0.localizedStandardContains(q) }
    }

    /// 在 Apple 地图里按全名搜索
    public var mapsURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: fullName)]
        return components?.url
    }
}

public enum CampusPlaces {
    private struct File: Decodable { let places: [CampusPlace] }

    public static let all: [CampusPlace] = {
        guard
            let url = Bundle.module.url(forResource: "campus-places", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else { return [] }
        return file.places
    }()

    /// 分类，保持数据里第一次出现的顺序
    public static var types: [String] {
        var seen = Set<String>()
        return all.map(\.type).filter { seen.insert($0).inserted }
    }

    /// 教室文案对应的地点（教学楼）。给课程详情“点地点打开地图”用。
    public static func place(forRoom room: String) -> CampusPlace? { all.first { $0.matches(room: room) } }
}

/// 教学楼平面图：教学楼 → 楼层图（远程 webp）
public struct TeachBuilding: Decodable, Sendable, Hashable, Identifiable {
    public struct Floor: Decodable, Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        /// 相对 `TeachBuildings.baseURL` 的路径
        public let image: String
    }

    public let id: String
    public let name: String
    public let floors: [Floor]
}

public enum TeachBuildings {
    private struct File: Decodable {
        let baseURL: String
        let buildings: [TeachBuilding]
    }

    private static let file: File? = {
        guard
            let url = Bundle.module.url(forResource: "teach-buildings", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    public static var all: [TeachBuilding] { file?.buildings ?? [] }

    public static func imageURL(_ floor: TeachBuilding.Floor) -> URL? {
        guard let base = file?.baseURL else { return nil }
        // 路径里有 “~” 等字符，按路径编码
        let path = floor.image.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? floor.image
        return URL(string: base + path)
    }
}
