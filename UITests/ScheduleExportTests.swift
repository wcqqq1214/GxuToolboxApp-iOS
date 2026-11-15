import XCTest

final class ScheduleExportTests: XCTestCase {
    @MainActor
    func testCachedScheduleExportsImageThroughShareSheet() {
        verifyImageExport(dark: false)
    }

    @MainActor
    func testCachedScheduleExportsImageInDarkLargeText() {
        verifyImageExport(dark: true)
    }

    @MainActor
    private func verifyImageExport(dark: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuDemoOffline", "-GxuTab", "schedule"]
        if dark {
            app.launchArguments += ["-gxu.theme.appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        let menu = app.buttons["课表操作"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.tap()
        let export = app.buttons["导出课表"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        XCTAssertTrue(app.navigationBars["导出课表"].waitForExistence(timeout: 10))
        let share = app.buttons["分享"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        XCTAssertTrue(share.isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = dark ? "本地课表导出深色大字" : "本地课表导出浅色"
        attachment.lifetime = .keepAlways
        add(attachment)
        share.tap()
        let more = app.cells.matching(NSPredicate(format: "label == 'View More' OR label == '显示更多' OR label == '查看更多'")).firstMatch
        if more.waitForExistence(timeout: 5) { more.tap() }
        let save = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '存储图像' OR label CONTAINS 'Save Image' OR label CONTAINS '保存图像'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
    }
}
