import Foundation
import GxuAuth
import GxuStorage
import GxuTestSupport
import ScheduleKit
import ExamKit
import FeatureCampus
import ClassWidgetKit
import Testing
@testable import GxuToolApp

@MainActor
struct HomeWidgetPublishTests {
    @Test func successfulHomeLoadMustPublishFreshWidgetSnapshot() async throws {
        StubURLProtocol.register(host: "file.unde.site") { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"holidays":[]}"#.utf8))
        }
        URLProtocol.registerClass(StubURLProtocol.self)
        defer { URLProtocol.unregisterClass(StubURLProtocol.self) }
        let backend = MockBackendAPI()
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations, ExamRepository.migrations, CampusFeature.migrations], studentId: "review-student-A")
        let today = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let term = TermStartDay(year: 2026, term: 1, day: today, week: 20)
        backend.stub("GET /jw/profile/startDay", json: try JSONEncoder().encode(["data": [term]]))
        backend.stub("GET /jw/schedule/personal", json: try JSONEncoder().encode(["data": Schedule(theoryList: [TheoryCourse(courseName: "Fetched by Home", weeks: Array(1...20), weekday: 2)])]))
        backend.stub("GET /jw/exam", json: #"{"data":[]}"#)
        await WidgetBridge.refresh(services: services)
        #expect(WidgetShared.currentSnapshot(store: services.shared)?.state == .missingStartDay)
        let model = HomeModel()
        await model.load(services: services)
        #expect(model.phase == .ready)
        let recomputed = await SnapshotProvider.compute(studentId: "review-student-A", database: services.database)
        #expect(recomputed.state == .ready)
        #expect(WidgetShared.currentSnapshot(store: services.shared)?.state == .ready)
    }
}
