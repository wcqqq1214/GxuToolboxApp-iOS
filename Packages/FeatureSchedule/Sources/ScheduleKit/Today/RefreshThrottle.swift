import Foundation

/// 按账号节流：同一个账号在 `minimumInterval` 内不重复联网刷新；换了账号要立刻刷新自己的数据。
/// （只用一个全局时间戳会让刚切换的新账号被上一个账号的刷新“挡掉”，拿不到任何数据。）
public struct RefreshThrottle: Sendable {
    private var last: [String: Date] = [:]

    public init() {}

    /// 该账号距上次刷新不到 `minimumInterval` 秒返回 false；否则记下时间并返回 true
    public mutating func shouldRefresh(for studentId: String, now: Date = .now, minimumInterval: TimeInterval) -> Bool {
        if let previous = last[studentId], now.timeIntervalSince(previous) < minimumInterval { return false }
        last[studentId] = now
        return true
    }

    /// 刷新被取消 / 没有真正完成时，让下一次不再被节流
    public mutating func forget(_ studentId: String) { last[studentId] = nil }
}
