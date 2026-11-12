import Foundation
import GxuAuth
import GxuFoundation
import GxuTestSupport
import Testing
@testable import FeatureCourse

@MainActor @Suite struct SelectedCoursesFailureTests {
    @Test func refreshFailureKeepsCachedCoursesAndShowsError() async throws {
        let url = try #require(Bundle.module.url(forResource: "selected-courses", withExtension: "json", subdirectory: "Fixtures"))
        let mock = MockBackendAPI()
        mock.stub("GET /jw/selected-courses", json: try Data(contentsOf: url))
        let services = AppServices.preview(backend: mock, features: [CourseFeature.migrations], studentId: "2025000000")
        let model = SelectedCoursesViewModel(services: services)
        await model.load()
        let count = model.courses.count
        #expect(count > 0 && model.error == nil)

        mock.stub("GET /jw/selected-courses", error: .network("offline"))
        await model.load()
        #expect(model.courses.count == count)
        #expect(model.error == .network("offline"))
    }
}
