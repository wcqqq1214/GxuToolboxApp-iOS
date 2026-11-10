import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureAccount

/// 按请求顺序返回不同内容的 OA 假服务；第 1 个请求故意慢，用来复现「旧请求后到达」
private final class SlowFirstProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var calls = 0
    nonisolated(unsafe) static var bodies: [String] = []
    static let lock = NSLock()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = Data()
        if let stream = request.httpBodyStream {
            stream.open(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: 4096); if n <= 0 { break }; body.append(buffer, count: n) }
            stream.close()
        }
        Self.lock.lock(); Self.calls += 1; let n = Self.calls; Self.bodies.append(String(decoding: body, as: UTF8.self)); Self.lock.unlock()
        let payload = #"{"code":200,"result":{"items":[{"id":\#(n),"fileName":"call\#(n)"}],"hasNextPage":true}}"#
        DispatchQueue.global().asyncAfter(deadline: .now() + (n == 1 ? 0.4 : 0)) {
            let response = HTTPURLResponse(url: self.request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Data(payload.utf8))
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

@Suite(.serialized) @MainActor
struct OAFilesModelRaceTests {
    private func services() -> AppServices {
        SlowFirstProtocol.calls = 0; SlowFirstProtocol.bodies = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SlowFirstProtocol.self]
        let store = InMemoryCredentialStore([.jw: Credential(username: "1", password: "p")])
        let jw = JwSessionManager(credentials: store, transport: BackendClient(session: BackendClient.makeSession(configuration: .ephemeral)))
        let oa = OASession(credentials: store, tokens: InMemoryTokenStore("tok"), configuration: configuration)
        let accounts = AccountCenter(credentials: store, jw: jw, oa: oa, states: [.jw: .authenticated, .oa: .authenticated], studentId: "1")
        return AppServices(backend: MockBackendAPI(), database: try! AppDatabase.inMemory(features: []), shared: InMemorySharedStore(), accounts: accounts)
    }

    /// 回归：切换文件类型时，慢的旧请求不能覆盖新结果，也不能把页码推进（否则「加载更多」会跳过第 2 页）
    @Test func staleReloadIsDiscardedAndPaginationStaysConsistent() async throws {
        let model = OAFilesModel(services: services())
        model.typeId = 102
        let first = Task { await model.reload() }
        try await Task.sleep(for: .milliseconds(100))
        model.typeId = 103
        let second = Task { await model.reload() }
        await first.value; await second.value
        #expect(model.rows.map(\.title) == ["call2"])
        await model.loadMoreIfNeeded(current: model.rows.last!)
        #expect(SlowFirstProtocol.bodies.last?.contains("\"page\":2") == true)
    }
}

struct OAFilesParsingTests {
    @Test func parsesListPage() throws {
        let json = #"""
        {"page":1,"pageSize":20,"total":2,"totalPages":1,"hasNextPage":true,"hasPrevPage":false,"items":[
          {"id":11,"fileName":"关于做好期末工作的通知","fileNum":"西大党〔2026〕27号","typeName":"党委文件","showTime":"2026-11-03 09:10:11","isUrgent":true,"isRead":false,"deptName":"党办"},
          {"id":"12","fileName":"另一份","fileNum":"","typeName":"","showTime":"2026-11-02 08:00:00","isUrgent":false,"isRead":true,"deptName":""},
          {"fileName":"缺 id 的条目会被丢弃"}
        ]}
        """#
        let page = try OAFilesAPI.parseList(Data(json.utf8))
        #expect(page.rows.map(\.id) == [11, 12])
        #expect(page.hasNext)
        #expect(page.rows[0].date == "2026-11-03" && page.rows[0].isUrgent && !page.rows[0].isRead)
        #expect(page.rows[0].department == "党办")
    }

    @Test func parsesSearchResultWhetherObjectOrArray() throws {
        let item = #"{"id":5,"title":"搜索到的文件","fileNum":"校办〔2026〕1号","department":"校办","docTime":"2026-09-01 10:00:00","typeName":"行政文件","isUrgent":false}"#
        let asObject = #"{"items":[\#(item)],"hasNextPage":false}"#
        let asArray = "[\(asObject)]"
        for json in [asObject, asArray] {
            let page = try OAFilesAPI.parseSearch(Data(json.utf8))
            #expect(page.rows.count == 1 && page.rows[0].title == "搜索到的文件" && page.rows[0].date == "2026-09-01")
            #expect(!page.hasNext)
        }
    }

    @Test func parsesDetailWithAttachments() throws {
        let json = #"{"id":9,"fileName":"通知","fileNum":"x","typeName":"t","deptName":"d","showTime":"2026-11-01 00:00:00","fileBody":"<p>正文</p>","pdfUrl":"https://oa.gxu.edu.cn/f/9.pdf","docxUrl":null}"#
        let detail = try OAFilesAPI.parseDetail(Data(json.utf8))
        #expect(detail.html == "<p>正文</p>")
        #expect(detail.pdfURL?.lastPathComponent == "9.pdf" && detail.docxURL == nil)
    }

    @Test func emptyBodyBecomesNil() throws {
        let detail = try OAFilesAPI.parseDetail(Data(#"{"id":1,"fileBody":null}"#.utf8))
        #expect(detail.html == nil)
    }

    @Test func malformedDetailThrows() {
        #expect(throws: (any Error).self) { try OAFilesAPI.parseDetail(Data(#"{"fileName":"no id"}"#.utf8)) }
        #expect(throws: (any Error).self) { try OAFilesAPI.parseList(Data("not json".utf8)) }
    }
}

@Suite struct OAHTMLTests {
    @Test func plainTextBodyKeepsLineBreaks() {
        let text = "各学院（部）：\n    为做好期末考试工作，现将有关事项通知如下。\n二、总体要求"
        #expect(OAHTML.isPlainText(text))
        #expect(OAHTML.wrap(text).contains(#"<body class="plain">"#))
    }

    @Test func markupBodyRendersAsHTML() {
        for body in ["<p>正文</p>", "第一行<br/>第二行", "<DIV>x</DIV>", #"<table border="1"><tr><td>a</td></tr></table>"#] {
            #expect(!OAHTML.isPlainText(body), "\(body)")
            #expect(OAHTML.wrap(body).contains(#"<body class="rich">"#))
        }
        // 行内标签不算块级：<span> / <b> 里的纯文本换行仍然要保留
        #expect(OAHTML.isPlainText("<b>通知</b>\n正文"))
    }
}
