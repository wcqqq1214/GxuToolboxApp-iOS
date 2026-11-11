import Foundation
import GxuAuth
import GxuStorage
import GxuTestSupport
import ScheduleKit
import ExamKit
import FeatureCampus
import Testing
@testable import GxuToolApp

@MainActor
struct HomeRaceTests {
    @Test func committedActivityUpdatesHomeWithoutSelectingATab() async throws {
        let backend = MockBackendAPI()
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations, ExamRepository.migrations, CampusFeature.migrations], studentId: "A")
        let today = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let term = TermStartDay(year: 2026, term: 1, day: today, week: 20)
        backend.stub("GET /jw/profile/startDay", json: try JSONEncoder().encode(["data": [term]]))
        backend.stub("GET /jw/schedule/personal", json: try JSONEncoder().encode(["data": Schedule(theoryList: [])]))
        let repository = ScheduleRepository(backend: backend, database: services.database)
        try await repository.refreshStartDays()
        try await repository.refreshSchedule(studentId: "A", term: term.academicTerm)
        let model = HomeModel()
        let observation = Task { await model.observeCache(services: services) }
        defer { observation.cancel() }
        for _ in 0..<200 where model.phase != .ready { try await Task.sleep(for: .milliseconds(10)) }
        try #require(model.phase == .ready)

        let activity = CustomActivity(id: "activity", name: "Lab", weekday: 1, begin: 1, end: 2, weekFrom: 1, weekTo: 1)
        try await repository.saveCustomActivity(activity, studentId: "A", term: term.academicTerm)
        for _ in 0..<200 where model.snapshot?.activities.isEmpty == true { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.snapshot?.activities.map(\.id) == [activity.id])
        #expect(backend.calls.count == 2)
    }

    @Test func logoutDuringCachedReloadMustNotRestorePreviousStudent() async throws {
        let backend = MockBackendAPI()
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations, ExamRepository.migrations, CampusFeature.migrations], studentId: "review-student-A")
        let today = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let term = TermStartDay(year: 2026, term: 1, day: today, week: 20)
        backend.stub("GET /jw/profile/startDay", json: try JSONEncoder().encode(["data": [term]]))
        backend.stub("GET /jw/schedule/personal", json: try JSONEncoder().encode(["data": Schedule(theoryList: [TheoryCourse(courseName: "Private course A", weeks: [1], weekday: 1)])]))
        let repository = ScheduleRepository(backend: backend, database: services.database)
        _ = try await repository.refreshStartDays()
        _ = try await repository.refreshSchedule(studentId: "review-student-A", term: term.academicTerm)
        let model = HomeModel()
        await model.reloadFromCache(services: services)
        #expect(model.phase == .ready)

        let release = DispatchSemaphore(value: 0)
        let writer = services.database.writer
        let (entered, writerEntered) = AsyncStream<Void>.makeStream()
        let blocker = Task.detached {
            try await writer.write { _ in
                writerEntered.yield(())
                release.wait()
            }
        }
        var entries = entered.makeAsyncIterator()
        _ = await entries.next()
        let (started, reloadStarted) = AsyncStream<Void>.makeStream()
        let staleReload = Task {
            reloadStarted.yield(())
            await model.reloadFromCache(services: services)
        }
        var starts = started.makeAsyncIterator()
        _ = await starts.next()
        await services.accounts.logout(.jw)
        await model.reloadFromCache(services: services)
        #expect(model.phase == .needsLogin)
        release.signal()
        try await blocker.value
        await staleReload.value
        #expect(model.phase == .needsLogin)
        #expect(model.snapshot == nil)
    }
}
