import Foundation
import GxuAuth
import GxuTestSupport
import Synchronization
import Testing
@testable import FeatureCampus

struct CampusNetworkTests {
    @Test func decodesUsageAndKeepsThePortalUnits() throws {
        let snapshot = try CampusNetworkPage.usage(in: dashboard, account: "demo-123")
        #expect(snapshot.period == "2026-11-01 至 2026-11-30")
        #expect(snapshot.used == "1536 M")
        #expect(snapshot.available == nil)
        #expect(snapshot.balance == "12.30 元")
        #expect(snapshot.plan == nil)
    }

    @Test func refusesAResponseForAnotherAccount() {
        #expect(throws: CampusNetworkError.accountMismatch) {
            try CampusNetworkPage.usage(in: dashboard, account: "demo-456")
        }
    }

    @Test func detectsLoginChallenge() throws {
        let form = try CampusNetworkPage.form(in: """
        <form method='post' action='/login/verify;jsessionid=demo'>
          <input name="checkcode" type="hidden" value="demo-challenge">
          <img src="/login/randomCode">
        </form>
        """)
        #expect(form.action == "/login/verify;jsessionid=demo")
        #expect(form.checkcode == "demo-challenge")
    }

    @Test func triesPasswordBeforeShowingCaptcha() async throws {
        enum Outcome: CaseIterable {
            case success, captchaRequired, wrongPassword
        }

        let credential = Credential(username: "demo-123", password: "fixture")
        let html = dashboard
        let form = #"<form action="/login/verify"><input name="checkcode" value="initial"><img src="/login/randomCode"></form>"#
        let image = Data([1, 2, 3])

        for outcome in Outcome.allCases {
            let steps = Mutex<[String]>([])
            let postCount = Mutex(0)
            StubURLProtocol.register(host: "self.gxu.edu.cn") { request in
                let url = try #require(request.url)
                let method = request.httpMethod ?? ""
                steps.withLock { $0.append("\(method) \(url.path)") }
                let count = postCount.withLock { $0 }
                var status = 200
                var headers: [String: String] = [:]
                let body: Data
                switch (method, url.path) {
                case ("GET", "/dashboard"):
                    if count == 2 || (count == 1 && outcome == .success) {
                        body = Data(html.utf8)
                    } else {
                        status = 302
                        headers["Location"] = "/login/"
                        body = Data()
                    }
                case ("GET", "/login"):
                    let feedback = switch (count, outcome) {
                    case (0, _), (_, .success): ""
                    case (_, .captchaRequired): "<script>(function(tip){})('请输入验证码');</script>"
                    case (_, .wrongPassword): "<script>(function(tip){})('密码错误');</script>"
                    }
                    body = Data((form.replacingOccurrences(of: "initial", with: count == 0 ? "initial" : "fresh") + feedback).utf8)
                case ("POST", "/login/verify"):
                    let encoded = Self.formBody(request)
                    if count == 0 {
                        #expect(encoded.contains("account=demo-123"))
                        #expect(!encoded.contains("code="))
                    } else {
                        #expect(encoded.contains("checkcode=fresh"))
                        #expect(encoded.contains("&code=1234"))
                    }
                    postCount.withLock { $0 += 1 }
                    status = 302
                    body = Data()
                case ("GET", "/login/randomCode"):
                    body = image
                default:
                    throw URLError(.badServerResponse)
                }
                return (try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)), body)
            }

            let session = CampusNetworkSession(configuration: StubURLProtocol.makeConfiguration())
            let passwordFlow = ["GET /dashboard", "GET /login", "POST /login/verify", "GET /dashboard"]
            switch outcome {
            case .success:
                guard case .usage(let usage) = try await session.refresh(credential) else {
                    Issue.record("Successful password login should return usage")
                    continue
                }
                #expect(usage.account == credential.username)
                #expect(steps.withLock { $0 } == passwordFlow)
            case .captchaRequired:
                guard case .captcha(let data) = try await session.refresh(credential) else {
                    Issue.record("The server required a captcha")
                    continue
                }
                #expect(data == image)
                #expect(steps.withLock { $0 } == passwordFlow + ["GET /login", "GET /login/randomCode"])
                _ = try await session.renewCaptcha()
                #expect(steps.withLock { $0 } == passwordFlow + [
                    "GET /login", "GET /login/randomCode", "GET /login", "GET /login/randomCode",
                ])
                #expect(try await session.submit("1234", credential: credential).account == credential.username)
            case .wrongPassword:
                await #expect(throws: CampusNetworkError.loginFailed) { try await session.refresh(credential) }
                #expect(steps.withLock { $0 } == passwordFlow + ["GET /login"])
            }
        }
    }

    private static func formBody(_ request: URLRequest) -> String {
        if let body = request.httpBody { return String(decoding: body, as: UTF8.self) }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var body = Data()
        var bytes = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&bytes, maxLength: bytes.count)
            guard count > 0 else { break }
            body.append(bytes, count: count)
        }
        return String(decoding: body, as: UTF8.self)
    }

    private var dashboard: String {
        """
        <div><label>账　号：</label><div>demo-123</div></div>
        <div><label>计费周期：</label><div><span>2026-11-01</span> 至 <span>2026-11-30</span></div></div>
        <dl><dt>1536 <small>M</small></dt><dd>已用流量</dd></dl>
        <dl><dt>-1 M</dt><dd>可用流量</dd></dl>
        <dl><dt>12.30 <small>元</small></dt><dd>账户余额</dd></dl>
        """
    }
}
