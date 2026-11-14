import XCTest

final class FeedbackDraftTests: XCTestCase {
    @MainActor
    func testDraftSurvivesRelaunchAndSuccessOpensMyFeedback() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "settings"]
        app.launch()
        openFeedback(app)
        let editor = app.textViews["反馈内容"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        if let value = editor.value as? String, !value.isEmpty {
            editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        editor.typeText("希望成绩页面能够保留搜索内容")
        app.terminate()
        app.launch()
        openFeedback(app)
        XCTAssertEqual(app.textViews["反馈内容"].value as? String, "希望成绩页面能够保留搜索内容")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "反馈类型")).firstMatch.tap()
        app.buttons["功能建议"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "问题模块")).firstMatch.tap()
        app.buttons["成绩"].tap()
        app.swipeUp()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "联系方式")).firstMatch.tap()
        app.buttons["邮箱"].tap()
        let contact = app.textFields["QQ号 / 微信号 / 邮箱"]
        contact.tap()
        if let value = contact.value as? String, value != contact.placeholderValue, !value.isEmpty {
            contact.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        contact.typeText("student@example.com")
        app.swipeUp()
        app.buttons["提交"].tap()
        XCTAssertTrue(app.alerts["提交成功"].waitForExistence(timeout: 10))
        app.alerts.buttons["查看我的反馈"].tap()
        XCTAssertTrue(app.navigationBars["我的反馈"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        openFeedback(app)
        XCTAssertEqual(app.textViews["反馈内容"].value as? String, "")
    }

    @MainActor
    func testDraftFormInDarkLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "settings", "-gxu.theme.appearance", "dark",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openFeedback(app)
        XCTAssertTrue(app.textViews["反馈内容"].waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "反馈草稿深色大字号"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func openFeedback(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 15))
        let entry = app.buttons["意见反馈"]
        for _ in 0..<8 {
            if entry.exists && entry.isHittable {
                entry.tap()
                return
            }
            app.swipeUp()
        }
        XCTFail("未找到意见反馈入口")
    }
}
