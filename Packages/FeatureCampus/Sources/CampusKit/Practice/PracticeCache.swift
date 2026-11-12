package enum PracticeCache {
    package static func key(for unifiedUsername: String) -> String {
        "unified:" + unifiedUsername
    }
}
