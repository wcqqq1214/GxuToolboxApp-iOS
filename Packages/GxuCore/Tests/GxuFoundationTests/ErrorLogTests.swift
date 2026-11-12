import Foundation
import Testing
@testable import GxuFoundation

struct ErrorLogTests {
    private func makeLog(maxBytes: Int = 256 * 1024) -> ErrorLog {
        ErrorLog(directory: FileManager.default.temporaryDirectory.appendingPathComponent("errlog-\(UUID().uuidString)"), maxBytes: maxBytes)
    }

    @Test func redactsSecretsAndLongNumbers() {
        let text = "POST http://x/y?username=2200000000&password=Abc123 failed; Authorization: Bearer eyJhbGciOi.abc.def password=hunter2 JSESSIONID=ABCDEF123 身份证 450000200001010019 手机 13800138000 学号2200000000"
        let out = ErrorLog.redact(text)
        for secret in ["2200000000", "Abc123", "eyJhbGciOi", "hunter2", "ABCDEF123", "450000200001010019", "13800138000"] {
            #expect(!out.contains(secret), "残留：\(secret)")
        }
        #expect(out.contains("http://x/y?…"))
    }

    @Test func keepsOrdinaryDiagnosticText() {
        #expect(ErrorLog.redact("GET /jw/exam → HTTP 500 (code 200)") == "GET /jw/exam → HTTP 500 (code 200)")
        #expect(ErrorLog.redact("network error -1009") == "network error -1009")
    }

    @Test func attemptReturnsValueOrRecordsFailure() async {
        struct Broken: Error, CustomStringConvertible { var description: String { "列缺失" } }
        let log = makeLog()
        #expect(log.attempt("cache", "读取成功", { 42 }) == 42)
        #expect(log.attempt("cache", "解码失败", { () throws -> Int in throw Broken() }) == nil)
        let asyncValue = await log.attempt("cache", "异步读取失败") { () async throws -> Int in throw Broken() }
        #expect(asyncValue == nil)
        let text = log.contents()
        #expect(!text.contains("读取成功"))
        #expect(text.contains("[cache] 解码失败：列缺失"))
        #expect(text.contains("[cache] 异步读取失败：列缺失"))
    }

    @Test func appendsLinesAndClears() {
        let log = makeLog()
        log.record("auth", "登录失败")
        log.recordRequest(method: "GET", url: URL(string: "http://api/jw/exam?year=2025&token=abc"), failure: "timeout")
        let text = log.contents()
        #expect(text.contains("[auth] 登录失败"))
        #expect(text.contains("[network] GET /jw/exam → timeout"))
        #expect(!text.contains("token") && !text.contains("2025"))
        log.clear()
        #expect(log.contents().isEmpty)
    }

    @Test func rotatesAndKeepsOnlyOnePreviousFile() {
        let log = makeLog(maxBytes: 400)
        for i in 0..<40 { log.record("test", "line \(i) 填充填充填充填充") }
        let text = log.contents()
        #expect(text.contains("line 39"))
        #expect(!text.contains("line 0 "))
        #expect(text.utf8.count <= 400 * 2 + 200)
    }

    @Test func concurrentWritesDoNotCrashOrLoseStructure() async {
        let log = makeLog()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 { group.addTask { log.record("c", "msg \(i)") } }
        }
        #expect(log.contents().split(separator: "\n").count == 50)
    }
}

struct KeychainAccessGroupTests {
    @Test func onlyAcceptsExpandedTeamPrefixedGroups() {
        #expect(GxuConfig.resolveKeychainAccessGroup("ABCDE12345.com.gxutool.ios") == "ABCDE12345.com.gxutool.ios")
        #expect(GxuConfig.resolveKeychainAccessGroup(nil) == nil)
        #expect(GxuConfig.resolveKeychainAccessGroup("") == nil)
        #expect(GxuConfig.resolveKeychainAccessGroup("$(AppIdentifierPrefix)com.gxutool.ios") == nil)
        #expect(GxuConfig.resolveKeychainAccessGroup("com.gxutool.ios") == nil)
        #expect(GxuConfig.resolveKeychainAccessGroup("abcde12345.com.gxutool.ios") == nil)
    }

    @Test func simulatorAlwaysUsesTheDefaultGroup() {
        #if targetEnvironment(simulator)
        #expect(GxuConfig.keychainAccessGroup == nil)
        #endif
    }
}

struct AppGroupConfigTests {
    @Test func appGroupResolutionFollowsTheInfoPlistValue() {
        #expect(GxuConfig.resolveAppGroupID(nil) == "group.com.gxutool.ios")
        #expect(GxuConfig.resolveAppGroupID("group.com.gxutool.ios") == "group.com.gxutool.ios")
        #expect(GxuConfig.resolveAppGroupID("group.com.alice.gxutool") == "group.com.alice.gxutool")
        #expect(GxuConfig.resolveAppGroupID("") == nil)
        #expect(GxuConfig.resolveAppGroupID("  ") == nil)
        #expect(GxuConfig.resolveAppGroupID("$(GXU_APP_GROUP)") == nil)
    }
}
