import Foundation

public struct CampusPlace: Decodable, Sendable, Hashable, Identifiable {
    public let type: String
    public let name: String
    public let fullName: String
    public let aliases: [String]
    public let pattern: String?

    public var id: String { fullName + name }

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

    public static var types: [String] {
        var seen = Set<String>()
        return all.map(\.type).filter { seen.insert($0).inserted }
    }

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

public struct TeachBuilding: Decodable, Sendable, Hashable, Identifiable {
    public struct Floor: Decodable, Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
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
        let path = floor.image.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? floor.image
        return URL(string: base + path)
    }
}
