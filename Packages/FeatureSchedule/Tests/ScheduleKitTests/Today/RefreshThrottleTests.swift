import Foundation
import Testing
@testable import ScheduleKit

struct RefreshThrottleTests {
    @Test func throttlesPerAccountNotGlobally() {
        var throttle = RefreshThrottle()
        let now = at("2026-09-07 08:00")
        let firstA = throttle.recordRefreshStartIfDue(for: "A", now: now, minimumInterval: 120)
        let secondA = throttle.recordRefreshStartIfDue(for: "A", now: now.addingTimeInterval(60), minimumInterval: 120)
        let firstB = throttle.recordRefreshStartIfDue(for: "B", now: now.addingTimeInterval(61), minimumInterval: 120)
        let laterA = throttle.recordRefreshStartIfDue(for: "A", now: now.addingTimeInterval(121), minimumInterval: 120)
        #expect(firstA)
        #expect(!secondA)
        #expect(firstB)
        #expect(laterA)
    }

    @Test func forgetAllowsImmediateRetry() {
        var throttle = RefreshThrottle()
        let now = at("2026-09-07 08:00")
        _ = throttle.recordRefreshStartIfDue(for: "A", now: now, minimumInterval: 120)
        throttle.forget("A")
        let retry = throttle.recordRefreshStartIfDue(for: "A", now: now.addingTimeInterval(1), minimumInterval: 120)
        #expect(retry)
    }
}
