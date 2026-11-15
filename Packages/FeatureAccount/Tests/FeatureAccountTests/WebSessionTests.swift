import Foundation
import Testing
import WebKit
@testable import FeatureAccount

@MainActor
struct WebSessionTests {
    @Test func sharedTemporarySessionDoesNotLeakIntoOrdinaryPages() async throws {
        let session = WebSession(isolated: true)
        let parent = WKWebViewConfiguration()
        parent.websiteDataStore = session.dataStore
        let popup = WKWebViewConfiguration()
        popup.websiteDataStore = session.dataStore
        let ordinary = WebSession(isolated: false)
        let domain = "export-\(UUID().uuidString.lowercased()).invalid"
        let cookie = try #require(HTTPCookie(properties: [.name: "JSESSIONID", .value: "synthetic", .domain: domain, .path: "/"]))
        await popup.websiteDataStore.httpCookieStore.setCookie(cookie)
        #expect(!popup.websiteDataStore.isPersistent)
        #expect(await parent.websiteDataStore.httpCookieStore.allCookies().contains { $0.domain == domain })
        #expect(await ordinary.dataStore.httpCookieStore.allCookies().allSatisfy { $0.domain != domain })
        let otherAccount = WebSession(isolated: true)
        #expect(await otherAccount.dataStore.httpCookieStore.allCookies().allSatisfy { $0.domain != domain })
        await session.dataStore.httpCookieStore.deleteCookie(cookie)
    }
}
