import XCTest

final class AnalyticsSettingsTests: XCTestCase {
    @MainActor
    func testProxyDisclosureRemainsVisibleBeforeLogin() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "settings"]
        app.launch()
        let account = app.staticTexts["教务账号"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 20))
        account.tap()
        let logout = app.buttons["退出登录"]
        XCTAssertTrue(logout.waitForExistence(timeout: 5))
        logout.tap()
        XCTAssertTrue(app.secureTextFields["教务系统密码"].waitForExistence(timeout: 5))
        let disclosure = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "第三方代理服务器 api.tool.gxutech.xyz")).firstMatch
        XCTAssertTrue(disclosure.exists)
        XCTAssertTrue(disclosure.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "login-disclosure"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars.buttons.firstMatch.tap()
        let attendance = app.staticTexts["考勤账号"].firstMatch
        XCTAssertTrue(attendance.waitForExistence(timeout: 5))
        attendance.tap()
        XCTAssertTrue(app.secureTextFields["考勤系统密码"].waitForExistence(timeout: 5))
        XCTAssertTrue(disclosure.exists)
        XCTAssertTrue(disclosure.isHittable)
    }

    @MainActor
    func testStatisticsPreferencePersistsInLightAndDarkAppearance() {
        continueAfterFailure = false
        let app = XCUIApplication()
        for appearance in ["Light", "Dark"] {
            app.launchArguments = ["-GxuDemo", "-AppleInterfaceStyle", appearance,
                                   "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launch()
            let settings = app.descendants(matching: .any).matching(identifier: "app-tab-bar").firstMatch.buttons["设置"]
            XCTAssertTrue(settings.waitForExistence(timeout: 20))
            settings.tap()
            let toggle = app.switches["分享使用统计"]
            reveal(toggle, in: app)
            XCTAssertTrue(toggle.isHittable)
            setEnabled(false, toggle: toggle, app: app)
            setEnabled(true, toggle: toggle, app: app)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "privacy-\(appearance)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
            app.launch()
            XCTAssertTrue(settings.waitForExistence(timeout: 20))
            settings.tap()
            reveal(toggle, in: app)
            XCTAssertEqual(toggle.value as? String, "1")
            setEnabled(false, toggle: toggle, app: app)
            app.terminate()
        }
    }
    @MainActor
    private func reveal(_ toggle: XCUIElement, in app: XCUIApplication) {
        let list = app.collectionViews.firstMatch
        let upper = app.frame.height * 0.2
        let lower = app.frame.height * 0.7
        for _ in 0..<40 {
            if toggle.exists, toggle.frame.minY > upper, toggle.frame.maxY < lower { break }
            let scrollUp = !toggle.exists || toggle.frame.maxY >= lower
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: scrollUp ? 0.6 : 0.4))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: scrollUp ? 0.4 : 0.6))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(toggle.isHittable)
        XCTAssertGreaterThan(toggle.frame.minY, upper)
        XCTAssertLessThan(toggle.frame.maxY, lower)
    }

    @MainActor
    private func setEnabled(_ enabled: Bool, toggle: XCUIElement, app: XCUIApplication) {
        let value = enabled ? "1" : "0"
        if toggle.value as? String != value {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: toggle)
        let result = XCTWaiter.wait(for: [changed], timeout: 5)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "statistics-\(value)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertEqual(result, .completed)
    }
}
