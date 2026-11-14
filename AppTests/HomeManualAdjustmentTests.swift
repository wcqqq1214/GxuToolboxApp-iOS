import ExamKit
import FeatureCampus
import Foundation
import GxuAuth
import GxuTestSupport
import ScheduleKit
import Testing
@testable import GxuToolApp

@MainActor
struct HomeManualAdjustmentTests {
    @Test func committedAdjustmentAndRestoreUpdateHomeWithoutNetworkRefresh() async throws {
        let backend = MockBackendAPI()
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations, ExamRepository.migrations, CampusFeature.migrations], studentId: "local-student")
        let day = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let term = TermStartDay(year: 2026, term: 1, day: day, week: 20)
        backend.stub("GET /jw/profile/startDay", json: try JSONEncoder().encode(["data": [term]]))
        let course = TheoryCourse(sectionRange: "1-2", begin: 1, end: 2, courseName: "本地测试课程", weeks: [1], weekday: 1)
        backend.stub("GET /jw/schedule/personal", json: try JSONEncoder().encode(["data": Schedule(theoryList: [course])]))
        let repository = ScheduleRepository(backend: backend, database: services.database)
        try await repository.refreshStartDays()
        try await repository.refreshSchedule(studentId: "local-student", term: term.academicTerm)
        let model = HomeModel()
        let observation = Task { await model.observeCache(services: services) }
        defer { observation.cancel() }
        for _ in 0..<200 where model.phase != .ready { try await Task.sleep(for: .milliseconds(10)) }
        let source = try #require(model.snapshot?.occurrences.first)
        let change = ManualCourseAdjustment(sourceID: source.id, week: 1, weekday: 2, begin: 3, end: 4, location: "新教室")
        try await repository.saveManualCourseAdjustments([change], studentId: "local-student", term: term.academicTerm)
        for _ in 0..<200 where model.snapshot?.occurrences.first?.manualAdjustmentID == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.snapshot?.occurrences.first?.course.locationText == "新教室")
        #expect(model.snapshot?.occurrences.first?.weekday == 2)
        try await repository.deleteManualCourseAdjustment(id: source.id, studentId: "local-student", term: term.academicTerm)
        for _ in 0..<200 where model.snapshot?.occurrences.first?.manualAdjustmentID != nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.snapshot?.occurrences == [source])
        #expect(backend.calls.count == 2)
    }
}
