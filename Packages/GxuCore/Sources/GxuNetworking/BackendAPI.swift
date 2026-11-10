import Foundation
import GxuFoundation

public struct DataEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: T
    public init(data: T) { self.data = data }
}

/// 自建后端客户端。自动带上教务 Cookie；遇到 401 或会话失效时，用 Keychain 里的账号自动重新登录一次后重试。
public protocol BackendAPI: Sendable {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T
}

public extension BackendAPI {
    /// GET 并解出 `{"data": ...}` 里的 data
    func getData<T: Decodable & Sendable>(_ path: String, query: [String: String] = [:], auth: AuthSystem? = .jw, as type: T.Type) async throws -> T {
        try await get(path, query: query, auth: auth, as: DataEnvelope<T>.self).data
    }

    func postData<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem? = .jw, as type: T.Type) async throws -> T {
        try await post(path, body: body, auth: auth, as: DataEnvelope<T>.self).data
    }
}

/// 会话失效时由认证层提供的“重新登录”能力。实现方必须自行合并并发调用。
public protocol SessionRenewer: Sendable {
    func renew(_ system: AuthSystem) async throws
    /// rejectedToken 是收到失效响应的请求所携带的 token。
    func renew(_ system: AuthSystem, rejectedToken: String?) async throws
}

public extension SessionRenewer {
    func renew(_ system: AuthSystem, rejectedToken: String?) async throws {
        try await renew(system)
    }
}
