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

    /// RN `matchByMatcher`：强匹配规则（正则，不分行首行尾以外的位置，命中即认定）
    func matchesStrongRule(_ text: String) -> Bool {
        guard let pattern, let regex = try? Regex(pattern) else { return false }
        return text.firstMatch(of: regex) != nil
    }

    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || name.localizedStandardContains(q) || fullName.localizedStandardContains(q)
            || aliases.contains { $0.localizedStandardContains(q) }
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

    /// RN `parseBuilding`：把地点文案解析成校园地点。先把连续空白合并成一个空格并去掉首尾空白，再依次：
    /// ① 强匹配规则（按数据顺序取第一条命中，越具体越靠前）；② 文案里包含地点的全称或名称（按数据顺序第一条）；
    /// ③ 文案里包含俗称，取最长的俗称（同样长取先出现的）。都不行返回 nil。
    public static func parse(_ raw: String) -> CampusPlace? {
        let text = raw.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let place = all.first(where: { $0.matchesStrongRule(text) }) { return place }
        if let place = all.first(where: { text.contains($0.fullName) || text.contains($0.name) }) { return place }
        var best: CampusPlace?
        var bestLength = 0
        for place in all {
            for alias in place.aliases where alias.count > bestLength && text.contains(alias) {
                best = place
                bestLength = alias.count
            }
        }
        return best
    }
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
