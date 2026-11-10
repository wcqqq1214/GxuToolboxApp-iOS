import Foundation
import GxuFoundation
import Testing
@testable import ScheduleKit

struct CancellationTests {
    @Test func recognizesCancellation() {
        #expect(CancellationError().isCancellation)
        #expect(URLError(.cancelled).isCancellation)
        #expect(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled).isCancellation)
        let wrapped = NSError(domain: "wrapper", code: 1, userInfo: [NSUnderlyingErrorKey: URLError(.cancelled)])
        #expect(wrapped.isCancellation)
    }

    @Test func realErrorsAreNotCancellation() {
        #expect(!URLError(.notConnectedToInternet).isCancellation)
        #expect(!GxuError.network("网络连接失败").isCancellation)
        #expect(!GxuError.sessionExpired(.jw).isCancellation)
    }
}
