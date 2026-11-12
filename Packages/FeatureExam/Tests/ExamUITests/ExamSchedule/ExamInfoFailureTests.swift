import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import GxuTestSupport
import Testing
@testable import ExamUI

@MainActor @Suite struct ExamInfoFailureTests {
    @Test func refreshFailureKeepsCachedExamsAndShowsError() async {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/exam", json: #"{"data":[{"id":"e1","course":"计算机网络原理","classroom":"6A-408","time":"2031-07-15(09:00-11:00)","type":"期末"}]}"#)
        let services = AppServices.preview(backend: mock, features: [ExamRepository.migrations], studentId: "2025000000")
        let model = ExamInfoViewModel(services: services)
        await model.resolveInitialTerm()
        await model.load()
        #expect(model.totalCount == 1 && model.error == nil)

        mock.stub("GET /jw/exam", error: .network("offline"))
        await model.load()
        #expect(model.totalCount == 1)
        #expect(model.error == .network("offline"))
    }
}
