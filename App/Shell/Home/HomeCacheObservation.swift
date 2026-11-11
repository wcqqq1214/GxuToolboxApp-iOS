import Foundation
import GxuStorage
import Synchronization

final class HomeCacheObservation: Sendable {
    struct Revision: Equatable, Sendable {
        var number: UInt64 = 0
        var interactive: UInt64 = 0
    }

    private struct Subscription {
        let id: UUID
        let continuation: AsyncStream<Void>.Continuation
    }

    private struct State {
        var revision: Revision? = Revision()
        var subscription: Subscription?
    }

    private final class Signal: Sendable {
        let state = Mutex(State())

        func fail() {
            let continuation = state.withLock { state in
                state.revision = nil
                return state.subscription?.continuation
            }
            continuation?.finish()
        }

        func changed(interactive: Bool) {
            let continuation = state.withLock { state -> AsyncStream<Void>.Continuation? in
                guard var revision = state.revision else { return nil }
                revision.number &+= 1
                if interactive { revision.interactive = revision.number }
                state.revision = revision
                return state.subscription?.continuation
            }
            continuation?.yield(())
        }
    }

    private let signal = Signal()
    private let registration: Task<[AnyDatabaseCancellable]?, Never>

    init(database: AppDatabase) {
        let signal = signal
        registration = Task {
            let writer = database.writer
            do {
                return try await writer.writeWithoutTransaction { _ in
                    let groups = [
                        (["schedule_snapshot", "term_start_day", "campus_calendar", "exam_info"], false),
                        (["schedule_conflict_choice", "schedule_custom_activity", "phy_experiment"], true)
                    ]
                    return groups.map { tables, interactive in
                        let observation = DatabaseRegionObservation(tracking: tables.map { Table<Row>($0) })
                        return observation.start(in: writer) { _ in
                            signal.fail()
                        } onChange: { _ in
                            signal.changed(interactive: interactive)
                        }
                    }
                }
            } catch {
                signal.fail()
                return nil
            }
        }
    }

    func currentRevision() async -> Revision? {
        guard await registration.value != nil else { return nil }
        return signal.state.withLock { $0.revision }
    }

    func hasInteractiveChange(since revision: Revision?) -> Bool {
        signal.state.withLock { $0.revision?.interactive != revision?.interactive }
    }

    func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        let signal = signal
        continuation.onTermination = { [weak signal] _ in
            signal?.state.withLock { state in
                if state.subscription?.id == id { state.subscription = nil }
            }
        }
        let previous = signal.state.withLock { state in
            let previous = state.subscription
            if state.revision != nil { state.subscription = Subscription(id: id, continuation: continuation) }
            return (previous, state.revision != nil)
        }
        previous.0?.continuation.finish()
        if !previous.1 { continuation.finish() }
        return stream
    }

    func resume() {
        signal.state.withLock { $0.subscription?.continuation }?.yield(())
    }

    deinit {
        signal.state.withLock { $0.subscription?.continuation }?.finish()
        registration.cancel()
    }
}
