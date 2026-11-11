import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage

@MainActor
public final class ScheduleRefreshCoordinator {
    private struct Session: Hashable {
        let database: ObjectIdentifier
        let login: UUID
        let studentId: String

        @MainActor
        init(services: AppServices, studentId: String) throws {
            database = ObjectIdentifier(services.database)
            login = services.accounts.jwSessionID
            self.studentId = studentId
            try validate(services.accounts)
        }

        @MainActor
        func validate(_ accounts: AccountCenter) throws {
            guard accounts.studentId == studentId, accounts.jwSessionID == login,
                  accounts.states[.jw] != .noAccount else { throw CancellationError() }
        }
    }

    private struct TermKey: Hashable {
        let session: Session
        let term: AcademicTerm
    }

    private let startDays = SharedRefresh<Session, [TermStartDay]>()
    private let schedules = SharedRefresh<TermKey, CachedSchedule>()
    private let calendars = SharedRefresh<ObjectIdentifier, CampusCalendar>()
    private let campusFetch: CampusCalendarRepository.Fetch

    public init(campusFetch: @escaping CampusCalendarRepository.Fetch = CampusCalendarRepository.urlSessionFetch) {
        self.campusFetch = campusFetch
    }

    public func refreshStartDays(services: AppServices, studentId: String, force: Bool = false) async throws -> [TermStartDay] {
        let session = try Session(services: services, studentId: studentId)
        let result = try await startDays.run(for: session, force: force) {
            try session.validate(services.accounts)
            return try await ScheduleRepository(backend: services.backend, database: services.database).refreshStartDays {
                try session.validate(services.accounts)
            }
        }
        try session.validate(services.accounts)
        return result
    }

    @discardableResult
    public func refreshSchedule(services: AppServices, studentId: String, term: AcademicTerm, force: Bool = false) async throws -> CachedSchedule {
        let session = try Session(services: services, studentId: studentId)
        let result = try await schedules.run(for: TermKey(session: session, term: term), force: force) {
            try session.validate(services.accounts)
            return try await ScheduleRepository(backend: services.backend, database: services.database).refreshSchedule(studentId: studentId, term: term) {
                try session.validate(services.accounts)
            }
        }
        try session.validate(services.accounts)
        return result
    }

    public func refreshCampusCalendar(database: AppDatabase, force: Bool = false) async throws -> CampusCalendar {
        try await calendars.run(for: ObjectIdentifier(database), force: force) { [campusFetch] in
            try await CampusCalendarRepository(database: database, fetch: campusFetch).refresh()
        }
    }
}

@MainActor
private final class SharedRefresh<Key: Hashable, Value: Sendable> {
    private let clock = ContinuousClock()
    private var running: [Key: Task<Value, any Error>] = [:]
    private var recent: [Key: (value: Value, expires: ContinuousClock.Instant)] = [:]

    func run(for key: Key, force: Bool, operation: @escaping @MainActor () async throws -> Value) async throws -> Value {
        try Task.checkCancellation()
        let now = clock.now
        recent = recent.filter { $0.value.expires > now }
        let task: Task<Value, any Error>
        if let existing = running[key] {
            task = existing
        } else if !force, let cached = recent[key] {
            return cached.value
        } else {
            recent[key] = nil
            task = Task {
                defer { running[key] = nil }
                let value = try await operation()
                recent[key] = (value, clock.now.advanced(by: .seconds(120)))
                return value
            }
            running[key] = task
        }
        let value = try await task.value
        try Task.checkCancellation()
        return value
    }
}
