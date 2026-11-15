import Foundation
import Testing
@testable import FeatureAccount

struct WebPageFailureTests {
    private let expected = URL(string: "https://jwxt2018.gxu.edu.cn/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html")!

    @Test func onlySchedulePageCanBeExported() {
        #expect(WebPageFailure.completedPage(expected, expected: expected) == nil)
        let login = URL(string: "https://jwxt2018.gxu.edu.cn/jwglxt/xtgl/login_slogin.html")!
        #expect(WebPageFailure.completedPage(login, expected: expected) == .loginRequired)
        #expect(WebPageFailure.completedPage(URL(string: "https://example.test/")!, expected: expected) == .unexpectedPage)
    }

    @Test func errorsDistinguishLoginFromServerFailure() {
        #expect(WebPageFailure.httpStatus(200) == nil)
        #expect(WebPageFailure.httpStatus(401) == .loginRequired)
        #expect(WebPageFailure.httpStatus(403) == .http(403))
        #expect(WebPageFailure.httpStatus(503) == .http(503))
        #expect(WebPageFailure.http(503).message.contains("503"))
        #expect(WebPageFailure.network("连接超时").message.contains("连接超时"))
    }
}
