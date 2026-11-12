import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Synchronization
import Testing
@testable import GxuAuth

@Suite(.serialized)
struct WjxtLogoutTests {
    private func makeCenter(_ creds: InMemoryCredentialStore, wjxt: WjxtSession) async -> AccountCenter {
        let client = BackendClient(session: BackendClient.makeSession(configuration: StubURLProtocol.makeConfiguration()))
        return await AccountCenter(credentials: creds, jw: JwSessionManager(credentials: creds, transport: client), wjxt: wjxt)
    }

    private func sessionCookie() -> HTTPCookie {
        HTTPCookie(properties: [.name: "ASP.NET_SessionId", .value: "SESS1", .domain: "wjxt.gxu.edu.cn", .path: "/"])!
    }

    @MainActor @Test func logoutOAClearsWjxtSession() async {
        let creds = InMemoryCredentialStore([.oa: Credential(username: "idcard", password: "pw")])
        let wjxt = WjxtSession(credentials: creds, configuration: StubURLProtocol.makeConfiguration())
        wjxt.cookies.setCookie(sessionCookie())
        #expect(!wjxt.sessionCookies().isEmpty)
        let center = await makeCenter(creds, wjxt: wjxt)
        await center.logout(.oa)
        #expect(wjxt.sessionCookies().isEmpty)
    }
}
