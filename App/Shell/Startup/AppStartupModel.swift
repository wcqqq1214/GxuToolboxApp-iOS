import Foundation
import GxuAuth
import GxuFoundation
import Observation

@MainActor @Observable
final class AppStartupModel {
    enum State {
        case idle
        case opening
        case ready(AppServices)
        case failed(String)
    }

    private(set) var state: State = .idle
    private let open: @MainActor () async throws -> AppServices

    init(open: @escaping @MainActor () async throws -> AppServices = AppComposition.live) {
        self.open = open
    }

    func start() async {
        switch state {
        case .opening, .ready: return
        case .idle, .failed: break
        }
        state = .opening
        do {
            state = .ready(try await open())
        } catch {
            let failure = error as NSError
            let code = "\(failure.domain) (\(failure.code))"
            ErrorLog.shared.record("database.open", code)
            state = .failed(code)
        }
    }
}
