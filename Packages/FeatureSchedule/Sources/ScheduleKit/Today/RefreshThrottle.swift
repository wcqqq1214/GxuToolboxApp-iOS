import Foundation

public struct RefreshThrottle: Sendable {
    private var lastRefreshStartByStudent: [String: Date] = [:]

    public init() {}

    public mutating func recordRefreshStartIfDue(for studentId: String, now: Date = .now, minimumInterval: TimeInterval) -> Bool {
        if let previous = lastRefreshStartByStudent[studentId], now.timeIntervalSince(previous) < minimumInterval { return false }
        lastRefreshStartByStudent[studentId] = now
        return true
    }

    public mutating func forget(_ studentId: String) { lastRefreshStartByStudent[studentId] = nil }
}
