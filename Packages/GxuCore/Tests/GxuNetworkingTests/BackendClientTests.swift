import Foundation
import GxuFoundation
import GxuTestSupport
import Testing
@testable import GxuNetworking

private struct Item: Decodable, Sendable, Equatable { let id: Int }
private struct Empty: Encodable, Sendable {}

private func response(_ url: URL, status: Int = 200, headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
}

private actor Counter { var n = 0; func next() -> Int { n += 1; return n } }

private final class CountingRenewer: SessionRenewer {
    let count = Counter()
    func renew(_ system: AuthSystem) async throws { _ = await count.next() }
}

private func makeClient(host: String, renewer: (any SessionRenewer)? = nil) -> BackendClient {
    BackendClient(baseURL: URL(string: "http://\(host)")!, session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()), renewer: renewer)
}

struct BackendClientTests {
    @Test func getDataUnwrapsEnvelopeAndSendsQuery() async throws {
        let host = "ok-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { request in
            #expect(request.url?.query == "term=1&year=2025")
            return (response(request.url!, headers: ["Content-Type": "application/json"]), Data(#"{"data":{"id":7}}"#.utf8))
        }
        let item = try await makeClient(host: host).getData("/jw/x", query: ["year": "2025", "term": "1"], as: Item.self)
        #expect(item == Item(id: 7))
    }

    @Test func httpErrorCarriesServerMessage() async {
        let host = "err-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { request in
            (response(request.url!, status: 500), Data(#"{"message":"教务繁忙"}"#.utf8))
        }
        await #expect(throws: GxuError.http(status: 500, message: "教务繁忙")) {
            try await makeClient(host: host).get("/a", query: [:], auth: .jw, as: Item.self)
        }
    }

    @Test func decodingFailureIsReported() async {
        let host = "dec-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { request in (response(request.url!), Data("{}".utf8)) }
        await #expect {
            try await makeClient(host: host).get("/a", query: [:], auth: nil, as: Item.self)
        } throws: { error in
            if case GxuError.decoding = error { return true } else { return false }
        }
    }

    @Test func expiredSessionRenewsOnceAndRetries() async throws {
        let host = "retry-\(UUID().uuidString).test"
        let calls = Counter()
        StubURLProtocol.register(host: host) { request in
            let n = (try? runBlocking { await calls.next() }) ?? 0
            if n == 1 { return (response(request.url!, status: 401), Data()) }
            return (response(request.url!), Data(#"{"data":{"id":1}}"#.utf8))
        }
        let renewer = CountingRenewer()
        let item = try await makeClient(host: host, renewer: renewer).getData("/a", as: Item.self)
        #expect(item == Item(id: 1))
        #expect(await renewer.count.n == 1)
    }

    @Test func stillExpiredAfterRenewThrowsSessionExpired() async {
        let host = "still-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { request in (response(request.url!, status: 401), Data()) }
        let renewer = CountingRenewer()
        await #expect(throws: GxuError.sessionExpired(.jw)) {
            try await makeClient(host: host, renewer: renewer).get("/a", query: [:], auth: .jw, as: Item.self)
        }
        #expect(await renewer.count.n == 1)
    }

    @Test func unauthenticatedRequestKeeps401AsHttpError() async {
        let host = "noauth-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { request in (response(request.url!, status: 401), Data()) }
        await #expect(throws: GxuError.http(status: 401, message: nil)) {
            try await makeClient(host: host).get("/a", query: [:], auth: nil, as: Item.self)
        }
    }

    @Test func redirectToLoginIsExpiry() {
        let url = URL(string: "http://x.test/a")!
        #expect(SessionExpiry.isExpired(response(url, status: 302, headers: ["Location": "https://jw/xtgl/login_slogin.html"]), data: Data()))
        #expect(!SessionExpiry.isExpired(response(url, status: 302, headers: ["Location": "/other"]), data: Data()))
    }

    @Test func loginHtmlIsExpiry() {
        let url = URL(string: "http://x.test/a")!
        let html = Data("<html><title>用户登录</title></html>".utf8)
        #expect(SessionExpiry.isExpired(response(url, headers: ["Content-Type": "text/html"]), data: html))
        #expect(!SessionExpiry.isExpired(response(url, headers: ["Content-Type": "application/json"]), data: html))
    }
}

/// URLProtocol 的 handler 是同步的，这里用信号量桥接 actor 计数
private func runBlocking<T: Sendable>(_ work: @escaping @Sendable () async -> T) throws -> T {
    let box = Box<T>()
    let semaphore = DispatchSemaphore(value: 0)
    Task { box.value = await work(); semaphore.signal() }
    semaphore.wait()
    return box.value!
}
private final class Box<T>: @unchecked Sendable { var value: T? }
