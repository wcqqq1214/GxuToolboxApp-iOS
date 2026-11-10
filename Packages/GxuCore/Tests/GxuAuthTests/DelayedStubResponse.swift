import Foundation
import Synchronization

final class DelayedStubResponse: Sendable {
    private let started = Mutex(false)
    private let resume = DispatchSemaphore(value: 0)

    func hold() throws {
        started.withLock { $0 = true }
        guard resume.wait(timeout: .now() + 8) == .success else { throw URLError(.timedOut) }
    }

    func waitForRequest() async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !started.withLock({ $0 }) {
            guard ContinuousClock.now < deadline else { throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func release() { resume.signal() }
}
