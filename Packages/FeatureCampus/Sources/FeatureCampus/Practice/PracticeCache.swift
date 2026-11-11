enum PracticeCache {
    static func key(for unifiedUsername: String) -> String {
        "unified:" + unifiedUsername
    }
}
