import Foundation

/// URL 查询串编码：只保留 RFC 3986 的非保留字符（字母、数字、`-._~`），其余全部百分号编码，和 JS 的 `encodeURIComponent` 一致。
/// `URLQueryItem` 不会编码 `+`，服务端按表单解码会把它当成空格（`C++` 变成 `C  `），所以所有拼查询串的地方都用这个。
public enum QueryString {
    private static let allowed: CharacterSet = {
        var set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        set.insert(charactersIn: "-._~")
        return set
    }()

    public static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    /// 按 key 排序，保证请求稳定（便于测试和缓存）
    public static func encode(_ items: [String: String]) -> String {
        items.sorted { $0.key < $1.key }.map { "\(encode($0.key))=\(encode($0.value))" }.joined(separator: "&")
    }
}
