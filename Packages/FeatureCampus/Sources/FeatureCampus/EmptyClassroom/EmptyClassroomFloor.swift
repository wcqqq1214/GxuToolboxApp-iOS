import Foundation

public enum EmptyClassroomFloor {
    public static let otherBuildingTitle = "其他楼栋"
    public static let otherFloorTitle = "其他楼层"
    private static let minFloor = 1, maxFloor = 30

    public struct FloorGroup: Sendable, Hashable, Identifiable {
        public var floor: Int?
        public var title: String
        public var rooms: [RoomRecord]
        public var id: String { floor.map(String.init) ?? "other" }
    }

    public struct BuildingGroup: Sendable, Hashable, Identifiable {
        public var building: String
        public var roomCount: Int
        public var title: String
        public var isOther: Bool
        public var id: String { building }
    }

    public struct SearchSection: Sendable, Hashable, Identifiable {
        public var building: String
        public var floor: Int?
        public var title: String
        public var rooms: [RoomRecord]
        public var id: String { "\(building)\u{0}\(floor.map(String.init) ?? "other")" }
    }

    public static func detectFloor(_ roomName: String, building: String? = nil) -> Int? {
        let text = stripBuilding(from: normalizeDigits(roomName).trimmingCharacters(in: .whitespacesAndNewlines), building: building)
        guard !text.isEmpty else { return nil }
        switch explicitFloor(in: text) {
        case .some(let result): return result
        case .none: return inferFromRoomNumber(text)
        }
    }

    private static func normalizeDigits(_ text: String) -> String {
        String(text.unicodeScalars.map { scalar -> Character in
            (0xFF10...0xFF19).contains(scalar.value) ? Character(UnicodeScalar(scalar.value - 0xFEE0)!) : Character(scalar)
        })
    }

    private static func stripBuilding(from text: String, building: String?) -> String {
        guard let building else { return text }
        let name = normalizeDigits(building).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return text }
        return text.replacingOccurrences(of: name, with: "", options: [.caseInsensitive, .literal]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func valid(_ floor: Int) -> Int? { (minFloor...maxFloor).contains(floor) ? floor : nil }

    private static func explicitFloor(in text: String) -> Int?? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2})\s*(层|[Ff](?![A-Za-z]))"#) else { return .none }
        let ns = text as NSString
        var sawUnderground = false
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let before = match.range.location > 0 ? ns.substring(with: NSRange(location: match.range.location - 1, length: 1)) : ""
            if before == "B" || before == "b" || before == "负" { sawUnderground = true; continue }
            return .some(valid(Int(ns.substring(with: match.range(at: 1))) ?? 0))
        }
        return sawUnderground ? .some(nil) : .none
    }

    private static func inferFromRoomNumber(_ text: String) -> Int? {
        let runs = text.split(whereSeparator: { !$0.isNumber }).map(String.init)
        guard let candidate = runs.reversed().first(where: { (2...4).contains($0.count) }) else { return nil }
        let digits = Array(candidate)
        let floor: Int
        if digits.count <= 3 {
            floor = digits[0] == "0" ? Int(String(digits[1])) ?? 0 : Int(String(digits[0])) ?? 0
        } else {
            floor = digits[0] == "0" ? Int(String(digits[1])) ?? 0 : Int(String(digits.prefix(2))) ?? 0
        }
        return valid(floor)
    }

    static func compareName(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.numeric], range: nil, locale: Locale(identifier: "zh-Hans-CN")) == .orderedAscending
    }

    public static func groupBuildings(_ summaries: [RoomBuildingSummary]) -> [BuildingGroup] {
        summaries.map {
            let isOther = $0.building.trimmingCharacters(in: .whitespaces).isEmpty
            return BuildingGroup(building: $0.building, roomCount: $0.roomCount, title: isOther ? otherBuildingTitle : $0.building, isOther: isOther)
        }
        .sorted { left, right in
            if left.isOther || right.isOther { return left.isOther && !right.isOther }
            return compareName(left.title, right.title)
        }
    }

    public static func groupRoomsByFloor(_ rooms: [RoomRecord]) -> [FloorGroup] {
        var order: [Int?] = []
        var map: [Int?: [RoomRecord]] = [:]
        for room in rooms.sorted(by: { compareName($0.name, $1.name) }) {
            let floor = detectFloor(room.name, building: room.building)
            if map[floor] == nil { order.append(floor) }
            map[floor, default: []].append(room)
        }
        return order
            .sorted { left, right in
                switch (left, right) {
                case (nil, nil): false
                case (nil, _): true
                case (_, nil): false
                case let (l?, r?): l < r
                }
            }
            .map { FloorGroup(floor: $0, title: $0.map { "\($0) 层" } ?? otherFloorTitle, rooms: map[$0] ?? []) }
    }

    public static func groupSearchResults(_ rooms: [RoomRecord]) -> [SearchSection] {
        let byBuilding = Dictionary(grouping: rooms, by: \.building)
        return groupBuildings(byBuilding.map { RoomBuildingSummary(building: $0.key, roomCount: $0.value.count) }).flatMap { building in
            groupRoomsByFloor(byBuilding[building.building] ?? []).map { floor in
                SearchSection(building: building.building, floor: floor.floor, title: "\(building.title) · \(floor.title)", rooms: floor.rooms)
            }
        }
    }
}
