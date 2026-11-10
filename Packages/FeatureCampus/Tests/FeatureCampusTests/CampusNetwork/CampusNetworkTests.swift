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
        for input in [
            #"<input name="checkcode" type="hidden" value="demo-challenge">"#,
            #"<input value = 'demo-challenge' type=hidden NAME = "checkcode">"#,
        ] {
            let form = try CampusNetworkPage.form(in: """
            <form method='post' action='/login/verify;jsessionid=demo'>
              <input data-name="checkcode" value="unrelated">
              \(input)
              <img src="/login/randomCode">
            </form>
            """)
            #expect(form.action == "/login/verify;jsessionid=demo")
            #expect(form.checkcode == "demo-challenge")
        }
    }

    @Test func triesPasswordBeforeShowingCaptcha() async throws {
        enum Outcome: CaseIterable {
            case success, captchaRequired, rejectedCaptcha, wrongPassword
        }

        let credential = Credential(username: "demo-123", password: "fixture")
        let html = dashboard
        let form = #"<form action="/login/verify"><input value="challenge-COUNT" name="checkcode"><img src="/login/randomCode"></form>"#
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
                    let signedIn = switch outcome {
                    case .success: count == 1
                    case .captchaRequired: count == 2
                    case .rejectedCaptcha: count == 3
                    case .wrongPassword: false
                    }
                    if signedIn {
                        body = Data(html.utf8)
                    } else {
                        status = 302
                        headers["Location"] = "/login/"
                        body = Data()
                    }
                case ("GET", "/login"):
                    let feedback = switch (count, outcome) {
                    case (0, _), (_, .success): ""
                    case (_, .captchaRequired), (_, .rejectedCaptcha): "<script>(function(tip){})('请输入验证码');</script>"
                    case (_, .wrongPassword): "<script>(function(tip){})('密码错误，当前无需验证码');</script>"
                    }
                    body = Data((form.replacingOccurrences(of: "COUNT", with: String(count)) + feedback).utf8)
                case ("POST", "/login/verify"):
                    let encoded = Self.formBody(request)
                    if count == 0 {
                        #expect(encoded.contains("account=demo-123"))
                        #expect(!encoded.contains("code="))
                    } else {
                        #expect(encoded.contains("checkcode=challenge-\(count)"))
                        let expectedCode = outcome == .rejectedCaptcha && count == 1 ? "0000" : "1234"
                        #expect(encoded.contains("&code=\(expectedCode)"))
                    }
                    postCount.withLock { $0 += 1 }
                    let feedback = switch (count, outcome) {
                    case (0, .captchaRequired): "<script>(function(tip){})('登录未通过');</script>"
                    case (1, .rejectedCaptcha): "<script>(function(tip){})('验证码错误，请重新输入验证码');</script>"
                    default: ""
                    }
                    status = feedback.isEmpty ? 302 : 200
                    body = Data(feedback.utf8)
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
                guard case .captcha(let data, rejected: false) = try await session.refresh(credential) else {
                    Issue.record("The server required a captcha")
                    continue
                }
                #expect(data == image)
                #expect(steps.withLock { $0 } == passwordFlow + ["GET /login", "GET /login/randomCode"])
                _ = try await session.renewCaptcha()
                #expect(steps.withLock { $0 } == passwordFlow + [
                    "GET /login", "GET /login/randomCode", "GET /login", "GET /login/randomCode",
                ])
                guard case .usage(let usage) = try await session.submit("1234", credential: credential) else {
                    Issue.record("Successful captcha login should return usage")
                    continue
                }
                #expect(usage.account == credential.username)
            case .rejectedCaptcha:
                guard case .captcha(_, rejected: false) = try await session.refresh(credential),
                      case .captcha(let data, rejected: true) = try await session.submit("0000", credential: credential),
                      case .usage(let usage) = try await session.submit("1234", credential: credential) else {
                    Issue.record("Wrong captcha should allow a second code without restarting login")
                    continue
                }
                #expect(data == image)
                #expect(usage.account == credential.username)
                #expect(steps.withLock { $0 } == passwordFlow + [
                    "GET /login", "GET /login/randomCode",
                    "POST /login/verify", "GET /dashboard", "GET /login", "GET /login/randomCode",
                    "POST /login/verify", "GET /dashboard",
                ])
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
