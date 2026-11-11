import Foundation
import GxuFoundation

public struct DataEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: T
    public init(data: T) { self.data = data }
}

public protocol BackendAPI: Sendable {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T
}

public extension BackendAPI {
    func getData<T: Decodable & Sendable>(_ path: String, query: [String: String] = [:], auth: AuthSystem? = .jw, as type: T.Type) async throws -> T {
        try await get(path, query: query, auth: auth, as: DataEnvelope<T>.self).data
    }

    func postData<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem? = .jw, as type: T.Type) async throws -> T {
        try await post(path, body: body, auth: auth, as: DataEnvelope<T>.self).data
    }
}

public protocol SessionRenewer: Sendable {
    func renew(_ system: AuthSystem) async throws
    func renew(_ system: AuthSystem, rejectedToken: String?) async throws
}

public extension SessionRenewer {
    func renew(_ system: AuthSystem, rejectedToken: String?) async throws {
        try await renew(system)
    }
}
