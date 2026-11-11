import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import ScheduleKit
import Testing

@MainActor
struct ScheduleRefreshCoordinatorTests {
    private let term = AcademicTerm(year: 2026, term: 1)

    @Test func sharesConcurrentAndRecentRequestsButForceRefreshes() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/profile/startDay", json: #"{"data":[{"year":2026,"term":1,"day":"2026-09-07","week":20}]}"#)
        backend.stub("GET /jw/schedule/personal", json: try JSONEncoder().encode(["data": Schedule(theoryList: [])]))
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "A")
        let refresh = ScheduleRefreshCoordinator()
        async let home = refresh.refreshStartDays(services: services, studentId: "A")
        async let schedule = refresh.refreshStartDays(services: services, studentId: "A")
        let (homeDays, scheduleDays) = try await (home, schedule)
        #expect(homeDays == scheduleDays)
        #expect(backend.calls == ["GET /jw/profile/startDay"])

        let first = try await refresh.refreshSchedule(services: services, studentId: "A", term: term)
        let reused = try await refresh.refreshSchedule(services: services, studentId: "A", term: term)
        #expect(first == reused)
        #expect(backend.calls.count == 2)

        try await refresh.refreshSchedule(services: services, studentId: "A", term: AcademicTerm(year: 2026, term: 2))
        try await refresh.refreshSchedule(services: services, studentId: "A", term: term, force: true)
        _ = try await refresh.refreshStartDays(services: services, studentId: "A", force: true)
        #expect(backend.getRequests.map { $0.query["term"] } == [nil, "1", "2", "1", nil])
    }

    @Test func failureCanBeRetriedAndAnotherSessionDoesNotReuseResults() async throws {
        let backend = MockBackendAPI()
        let a = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "A")
        let otherAccount = AppServices.preview(backend: backend, studentId: "A")
        let b = AppServices(backend: backend, database: a.database, shared: a.shared, accounts: otherAccount.accounts)
        let refresh = ScheduleRefreshCoordinator()
        await #expect(throws: GxuError.self) {
            try await refresh.refreshSchedule(services: a, studentId: "A", term: term)
        }
        let first = Schedule(theoryList: [TheoryCourse(courseName: "A1", weeks: [1], weekday: 1)])
        backend.stub("GET /jw/schedule/personal", json: try JSONEncoder().encode(["data": first]))
        #expect(try await refresh.refreshSchedule(services: a, studentId: "A", term: term).schedule == first)
        let second = Schedule(theoryList: [TheoryCourse(courseName: "A2", weeks: [1], weekday: 1)])
        backend.stub("GET /jw/schedule/personal", json: try JSONEncoder().encode(["data": second]))
        #expect(try await refresh.refreshSchedule(services: b, studentId: "A", term: term).schedule == second)
        #expect(backend.calls.count == 3)
    }

    @Test func loggingOutDuringARequestPreventsItsResultFromBeingSaved() async throws {
        let (started, requestStarted) = AsyncStream<Void>.makeStream()
        let (response, releaseResponse) = AsyncStream<Void>.makeStream()
        let backend = DelayedScheduleBackend(requestStarted: requestStarted, response: response)
        let preview = AppServices.preview(features: [ScheduleKit.migrations], studentId: "A")
        let services = AppServices(backend: backend, database: preview.database, shared: preview.shared, accounts: preview.accounts)
        let refresh = ScheduleRefreshCoordinator()
        let request = Task { try await refresh.refreshSchedule(services: services, studentId: "A", term: term) }
        var entries = started.makeAsyncIterator()
        _ = await entries.next()
        await services.accounts.logout(.jw)
        releaseResponse.finish()
        await #expect(throws: CancellationError.self) { try await request.value }
        let repo = ScheduleRepository(backend: backend, database: services.database)
        #expect(try await repo.cachedSchedule(studentId: "A", term: term) == nil)
    }
}

private struct DelayedScheduleBackend: BackendAPI {
    let requestStarted: AsyncStream<Void>.Continuation
    let response: AsyncStream<Void>

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        requestStarted.yield(())
        for await _ in response { break }
        let schedule = Schedule(theoryList: [TheoryCourse(courseName: "Old", weeks: [1], weekday: 1)])
        return try JSONDecoder().decode(type, from: JSONEncoder().encode(["data": schedule]))
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("unstubbed")
    }
}
