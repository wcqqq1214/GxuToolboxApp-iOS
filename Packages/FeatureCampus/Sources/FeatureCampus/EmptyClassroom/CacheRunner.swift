import Foundation
import GxuFoundation

public struct CacheRunnerRange: Sendable, Equatable {
    public var year: Int
    public var term: Int
    public var week: Int
    public init(year: Int, term: Int, week: Int) { (self.year, self.term, self.week) = (year, term, week) }
}

public struct CacheRunResult: Sendable, Equatable {
    public var completedDays: [Int]
    public var complete: Bool
    public var canceled: Bool
}

public struct CacheRunnerDeps: Sendable {
    public var completedDays: @Sendable (CacheRunnerRange) async throws -> [Int]
    public var fetchDay: @Sendable (CacheRunnerRange, Int, @escaping @Sendable (Int, Int) -> Void) async throws -> DayPayload
    public var saveDay: @Sendable (CacheRunnerRange, Int, DayPayload) async throws -> Void
    public var completeWeek: @Sendable (CacheRunnerRange) async throws -> Void
    public var beforeFirstRequest: @Sendable () -> Void
    public var onProgress: @Sendable (_ day: Int, _ period: Int, _ completedDays: [Int]) -> Void
    public var onDaySaved: @Sendable (_ day: Int, _ completedDays: [Int]) -> Void
    public var shouldCancel: @Sendable () -> Bool

    public init(
        completedDays: @escaping @Sendable (CacheRunnerRange) async throws -> [Int],
        fetchDay: @escaping @Sendable (CacheRunnerRange, Int, @escaping @Sendable (Int, Int) -> Void) async throws -> DayPayload,
        saveDay: @escaping @Sendable (CacheRunnerRange, Int, DayPayload) async throws -> Void,
        completeWeek: @escaping @Sendable (CacheRunnerRange) async throws -> Void,
        beforeFirstRequest: @escaping @Sendable () -> Void = {},
        onProgress: @escaping @Sendable (Int, Int, [Int]) -> Void = { _, _, _ in },
        onDaySaved: @escaping @Sendable (Int, [Int]) -> Void = { _, _ in },
        shouldCancel: @escaping @Sendable () -> Bool = { false }
    ) {
        self.completedDays = completedDays; self.fetchDay = fetchDay; self.saveDay = saveDay; self.completeWeek = completeWeek
        self.beforeFirstRequest = beforeFirstRequest; self.onProgress = onProgress; self.onDaySaved = onDaySaved; self.shouldCancel = shouldCancel
    }
}

public enum CacheRunner {
    public static func runWeek(_ range: CacheRunnerRange, deps: CacheRunnerDeps) async throws -> CacheRunResult {
        var completed = Array(Set(try await deps.completedDays(range).filter { (1...EmptyClassroomConstants.days).contains($0) })).sorted()
        if completed.count == EmptyClassroomConstants.days {
            try await deps.completeWeek(range)
            return CacheRunResult(completedDays: completed, complete: true, canceled: false)
        }
        var canceled = false
        var first = true
        for day in 1...EmptyClassroomConstants.days {
            if completed.contains(day) { continue }
            if deps.shouldCancel() || Task.isCancelled { canceled = true; break }
            if first { first = false; deps.beforeFirstRequest() }
            let payload: DayPayload
            do {
                let snapshot = completed
                payload = try await deps.fetchDay(range, day) { d, p in deps.onProgress(d, p, snapshot) }
            } catch is CancellationError {
                canceled = true
                break
            } catch EmptyClassroomError.canceled {
                canceled = true
                break
            }
            try await deps.saveDay(range, day, payload)
            completed = (completed + [day]).sorted()
            deps.onDaySaved(day, completed)
            if deps.shouldCancel() || Task.isCancelled { canceled = true; break }
        }
        let complete = completed.count == EmptyClassroomConstants.days
        if complete { try await deps.completeWeek(range) }
        return CacheRunResult(completedDays: completed, complete: complete, canceled: canceled)
    }

    public static func remainingCooldown(lastStartedAt: Date?, now: Date = .now, cooldown: TimeInterval = EmptyClassroomConstants.cooldown) -> TimeInterval {
        guard let lastStartedAt else { return 0 }
        return max(0, cooldown - now.timeIntervalSince(lastStartedAt))
    }
}
