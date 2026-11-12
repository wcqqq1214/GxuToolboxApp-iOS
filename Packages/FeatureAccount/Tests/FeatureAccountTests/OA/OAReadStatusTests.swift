import Foundation
import GxuAuth
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureAccount

private final class OAReadProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var rejectRead = false
    nonisolated(unsafe) static var rejectDetail = false
    nonisolated(unsafe) static var readRequests = 0
    nonisolated(unsafe) static var recordedID: Int?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        var payload = #"{"code":200,"result":{"items":[{"id":7,"isRead":false}],"hasNextPage":false}}"#
        if path.hasSuffix("/login") {
            payload = #"{"code":200,"result":{"accessToken":"other-account-token"}}"#
        } else if path.hasSuffix("/detail") {
            payload = Self.rejectDetail ? #"{"code":500}"# : #"{"code":200,"result":{"id":7,"fileBody":"正文"}}"#
        } else if path.hasSuffix("/record-read") {
            Self.readRequests += 1
            var data = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(buffer, count: count)
                }
            }
            Self.recordedID = (try? JSONSerialization.jsonObject(with: data) as? [String: Int])?["fileId"]
            payload = Self.rejectRead || request.httpMethod != "POST" ? #"{"code":500}"# : #"{"code":200,"result":null}"#
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(payload.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) @MainActor
struct OAReadStatusTests {
    private func services() -> AppServices {
        OAReadProtocol.rejectRead = false
        OAReadProtocol.rejectDetail = false
        OAReadProtocol.readRequests = 0
        OAReadProtocol.recordedID = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OAReadProtocol.self]
        let store = InMemoryCredentialStore([.jw: Credential(username: "1", password: "p"), .oa: Credential(username: "account-a", password: "p")])
        let jw = JwSessionManager(credentials: store, transport: BackendClient(session: BackendClient.makeSession(configuration: .ephemeral)))
        let oa = OASession(credentials: store, tokens: InMemoryTokenStore("test-token"), configuration: configuration)
        let accounts = AccountCenter(credentials: store, jw: jw, oa: oa, states: [.jw: .authenticated, .oa: .authenticated], studentId: "1")
        return AppServices(backend: MockBackendAPI(), database: try! AppDatabase.inMemory(features: []), shared: InMemorySharedStore(), accounts: accounts)
    }

    @Test func accountSwitchDoesNotInheritReadStatus() async throws {
        let services = services()
        try await services.accounts.login(.oa, username: "account-a", password: "test")
        let list = OAFilesModel(services: services)
        await list.reload()
        let row = try #require(list.rows.first)
        let detail = OAFileDetailModel(row: row, services: services)
        await detail.load()
        #expect(detail.isReadRecorded)
        list.didRead(try #require(detail.readReceipt))
        await services.accounts.logout(.oa)
        try await services.accounts.login(.oa, username: "account-b", password: "test")
        await list.reload()
        #expect(list.rows.first?.isRead == false)
    }

    @Test func delayedReceiptDoesNotMarkAnotherAccountRead() async throws {
        let services = services()
        let list = OAFilesModel(services: services)
        await list.reload()
        let row = try #require(list.rows.first)
        let detail = OAFileDetailModel(row: row, services: services)
        await detail.load()
        let receipt = try #require(detail.readReceipt)
        await services.accounts.logout(.oa)
        try await services.accounts.login(.oa, username: "account-b", password: "test")
        await list.reload()
        list.didRead(receipt)
        #expect(list.rows.first?.isRead == false)
        await list.reload()
        #expect(list.rows.first?.isRead == false)
    }

    @Test func oldDetailCannotRetryForNewAccount() async throws {
        let services = services()
        let list = OAFilesModel(services: services)
        await list.reload()
        let detail = OAFileDetailModel(row: try #require(list.rows.first), services: services)
        OAReadProtocol.rejectRead = true
        await detail.load()
        #expect(!detail.isReadRecorded)
        await services.accounts.logout(.oa)
        try await services.accounts.login(.oa, username: "account-b", password: "test")
        OAReadProtocol.rejectRead = false
        await detail.recordRead()
        #expect(!detail.isReadRecorded)
        #expect(OAReadProtocol.readRequests == 1)
        #expect(detail.readError != nil)
    }

    @Test func successfulReadClearsDotAndSurvivesStaleReload() async throws {
        let services = services()
        let list = OAFilesModel(services: services)
        await list.reload()
        let row = try #require(list.rows.first)
        #expect(!row.isRead)
        let detail = OAFileDetailModel(row: row, services: services)
        await detail.load()
        #expect(detail.isReadRecorded)
        #expect(OAReadProtocol.recordedID == row.id)
        if detail.isReadRecorded { list.didRead(try #require(detail.readReceipt)) }
        #expect(list.rows.first?.isRead == true)
        await list.reload()
        #expect(list.rows.first?.isRead == true)
        await detail.recordRead()
        #expect(OAReadProtocol.readRequests == 1)
    }

    @Test func failedRecordKeepsContentAndCanRetry() async throws {
        let services = services()
        let list = OAFilesModel(services: services)
        await list.reload()
        let detail = OAFileDetailModel(row: try #require(list.rows.first), services: services)
        OAReadProtocol.rejectRead = true
        await detail.load()
        #expect(detail.detail != nil)
        #expect(!detail.isReadRecorded)
        #expect(detail.readError != nil)
        #expect(list.rows.first?.isRead == false)
        OAReadProtocol.rejectRead = false
        await detail.recordRead()
        #expect(detail.isReadRecorded)
        #expect(detail.readError == nil)
    }

    @Test func failedDetailDoesNotRecordRead() async throws {
        let services = services()
        let list = OAFilesModel(services: services)
        await list.reload()
        let detail = OAFileDetailModel(row: try #require(list.rows.first), services: services)
        OAReadProtocol.rejectDetail = true
        await detail.load()
        #expect(!detail.isReadRecorded)
        #expect(OAReadProtocol.readRequests == 0)
    }
}
