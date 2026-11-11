import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import Synchronization

public final class MockBackendAPI: BackendAPI {
    public struct GetRequest: Sendable {
        public let path: String
        public let query: [String: String]
        public let auth: AuthSystem?
    }

    private struct State {
        var responses: [String: Result<Data, GxuError>] = [:]
        var calls: [String] = []
        var getRequests: [GetRequest] = []
    }
    private let state = Mutex(State())

    public init() {}

    public func stub(_ key: String, json: Data) { state.withLock { $0.responses[key] = .success(json) } }
    public func stub(_ key: String, json: String) { stub(key, json: Data(json.utf8)) }
    public func stub(_ key: String, error: GxuError) { state.withLock { $0.responses[key] = .failure(error) } }

    public var calls: [String] { state.withLock { $0.calls } }
    public var getRequests: [GetRequest] { state.withLock { $0.getRequests } }

    public func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        try respond("GET \(path)", getRequest: GetRequest(path: path, query: query, auth: auth), as: type)
    }

    public func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        try respond("POST \(path)", as: type)
    }

    private func respond<T: Decodable>(_ key: String, getRequest: GetRequest? = nil, as type: T.Type) throws -> T {
        let result = state.withLock { state -> Result<Data, GxuError>? in
            state.calls.append(key)
            if let getRequest { state.getRequests.append(getRequest) }
            return state.responses[key]
        }
        guard let result else { throw GxuError.network("MockBackendAPI 未预设 \(key)") }
        let data = try result.get()
        do { return try JSONDecoder().decode(type, from: data) } catch {
            throw GxuError.decoding(String(describing: error))
        }
    }
}

public func loadFixture(_ name: String, bundle: Bundle) throws -> Data {
    for candidate in [name, name + ".json"] {
        let url = bundle.url(forResource: candidate, withExtension: nil)
            ?? bundle.url(forResource: candidate, withExtension: nil, subdirectory: "Fixtures")
        if let url { return try Data(contentsOf: url) }
    }
    throw GxuError.invalidData("找不到 fixture：\(name)")
}

public final class InMemorySharedStore: SharedStore {
    private let storage = Mutex<[String: Data]>([:])
    public init() {}

    public func value<T: Codable & Sendable>(_ key: SharedKey<T>) -> T? {
        guard let data = storage.withLock({ $0[key.name] }) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func set<T: Codable & Sendable>(_ value: T?, for key: SharedKey<T>) {
        let data = value.flatMap { try? JSONEncoder().encode($0) }
        storage.withLock { $0[key.name] = data }
    }
}

public final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    public typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    private static let handlers = Mutex<[String: Handler]>([:])

    public static func register(host: String, handler: @escaping Handler) {
        handlers.withLock { $0[host] = handler }
    }

    public static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return configuration
    }

    public override class func canInit(with request: URLRequest) -> Bool { true }
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    public override func startLoading() {
        let handler = request.url?.host.flatMap { host in Self.handlers.withLock { $0[host] } }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    public override func stopLoading() {}
}

extension AppServices {
    @MainActor
    public static func preview(
        backend: MockBackendAPI = MockBackendAPI(),
        features: [FeatureMigrations] = [],
        studentId: String = "2025000000",
        signedIn: Bool = true
    ) -> AppServices {
        let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
        let store = InMemoryCredentialStore(signedIn ? [.jw: Credential(username: studentId, password: "preview")] : [:])
        let jw = JwSessionManager(credentials: store, transport: client)
        return AppServices(
            backend: backend,
            database: try! AppDatabase.inMemory(features: features),
            shared: InMemorySharedStore(),
            accounts: AccountCenter(credentials: store, jw: jw, states: signedIn ? [.jw: .authenticated] : [:], studentId: signedIn ? studentId : nil)
        )
    }

    public static var preview: AppServices {
        MainActor.assumeIsolated { preview() }
    }
}
