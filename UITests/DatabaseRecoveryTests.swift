import XCTest

@MainActor
final class DatabaseRecoveryTests: XCTestCase {
    func testCorruptDatabaseShowsRecoveryAndCanRetryAndExport() {
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDatabaseFailure"]
        app.launch()
        let retry = app.buttons["重试打开"]
        XCTAssertTrue(retry.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["本地数据暂时无法打开"].exists)
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
        let recovery = XCTAttachment(screenshot: app.screenshot())
        recovery.name = "database-recovery"
        recovery.lifetime = .keepAlways
        add(recovery)
        app.buttons["导出原始数据备份"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 60))
        let export = XCTAttachment(screenshot: app.screenshot())
        export.name = "database-backup-export"
        export.lifetime = .keepAlways
        add(export)
        cancel.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertTrue(retry.isEnabled)
    }
}
