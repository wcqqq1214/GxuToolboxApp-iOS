import Foundation
import GxuAuth
import GxuTestSupport
import Testing
@testable import GxuToolApp

@MainActor
struct TeacherLookupTests {
    @Test func retriesFailedLookupAndCachesSuccessfulResult() async {
        let backend = MockBackendAPI()
        let services = AppServices.preview(backend: backend)
        let name = "教师演示-" + UUID().uuidString
        let route = "GET /teachers/search"
        backend.stub(route, error: .network("offline"))

        let failed = await TeacherLookup.matches("  \(name)\n", services: services)
        #expect(failed == nil)

        backend.stub(route, json: #"{"data":{"list":[{"id":"1","name":"教师甲","unit":"演示学院"}],"pages":1,"total":1}}"#)
        let loaded = await TeacherLookup.matches(name, services: services)
        #expect(loaded?.map(\.name) == ["教师甲"])
        #expect(loaded?.first?.unit == "演示学院")

        backend.stub(route, error: .network("offline"))
        let cached = await TeacherLookup.matches("  \(name)  ", services: services)
        #expect(cached == loaded)
        #expect(backend.calls == [route, route])

        let requests = backend.getRequests
        let query = ["q": name, "page": "1"]
        #expect(requests.map(\.path) == ["/teachers/search", "/teachers/search"])
        #expect(requests.map(\.query) == [query, query])
        #expect(requests.map(\.auth) == [nil, nil])
    }
}
