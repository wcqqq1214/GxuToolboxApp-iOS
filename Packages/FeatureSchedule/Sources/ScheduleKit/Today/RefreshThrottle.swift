import Foundation

public struct RefreshThrottle: Sendable {
    private var last: [String: Date] = [:]

    public init() {}

    public mutating func shouldRefresh(for studentId: String, now: Date = .now, minimumInterval: TimeInterval) -> Bool {
        if let previous = last[studentId], now.timeIntervalSince(previous) < minimumInterval { return false }
        last[studentId] = now
        return true
    }

    public mutating func forget(_ studentId: String) { last[studentId] = nil }
}
