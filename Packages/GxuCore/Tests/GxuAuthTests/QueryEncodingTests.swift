import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Synchronization
import Testing
@testable import GxuAuth

struct QueryEncodingTests {
    @Test func plusAndReservedCharactersAreEncoded() {
        #expect(QueryString.encode(["q": "C++ a&b=c/d"]) == "q=C%2B%2B%20a%26b%3Dc%2Fd")
        #expect(QueryString.encode(["q": "王"]) == "q=%E7%8E%8B")
        #expect(QueryString.encode(["b": "2", "a": "1"]) == "a=1&b=2")
    }

    @Test func backendClientSendsEncodedPlus() async throws {
        let host = "q-\(UUID().uuidString).test"
        let seen = Mutex("")
        StubURLProtocol.register(host: host) { request in
            seen.withLock { $0 = request.url!.absoluteString }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"data":1}"#.utf8))
        }
        let client = BackendClient(baseURL: URL(string: "http://\(host)")!, session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
        _ = try await client.getData("/x", query: ["q": "C++ a&b"], auth: nil, as: Int.self)
        #expect(seen.withLock { $0 }.hasSuffix("/x?q=C%2B%2B%20a%26b"))
    }
}
