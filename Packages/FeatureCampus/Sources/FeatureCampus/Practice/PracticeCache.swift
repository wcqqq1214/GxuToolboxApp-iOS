enum PracticeCache {
    static func key(for unifiedUsername: String) -> String {
        // 旧记录以教务学号保存，无法确认由哪个统一认证账号获取。
        "unified:" + unifiedUsername
    }
}
