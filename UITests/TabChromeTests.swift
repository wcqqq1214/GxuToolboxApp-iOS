import XCTest

@MainActor
final class TabChromeTests: XCTestCase {
    func testSignedOutLaunchHasOnlyStaticNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-GxuTab", "home"]
        app.launch()
        XCTAssertTrue(app.staticTexts["还没有登录教务系统"].waitForExistence(timeout: 30))
        let tabs = app.descendants(matching: .any).matching(identifier: "app-tab-bar").firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        XCTAssertTrue(tabs.buttons["tab-home"].isHittable)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "signed-out-static-navigation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFixedNavigationAndScheduleOnlyAccessory() {
        verifyTabChrome(legacy: false)
    }

    func testLegacyNavigationAndScheduleOnlyAccessory() {
        verifyTabChrome(legacy: true)
    }

    private func verifyTabChrome(legacy: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "schedule", "-GxuPickEvent", "holiday"]
        if legacy { app.launchArguments += ["-GxuForceLegacy"] }
        app.launch()
        let tabs = app.descendants(matching: .any).matching(identifier: "app-tab-bar").firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        let accessory = app.descendants(matching: .any).matching(identifier: "next-event-accessory").firstMatch
        XCTAssertTrue(accessory.waitForExistence(timeout: 20))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        let initialFrame = tabs.frame
        app.swipeUp()
        app.swipeUp()
        XCTAssertEqual(tabs.frame.height, initialFrame.height, accuracy: 2)
        XCTAssertEqual(tabs.frame.minY, initialFrame.minY, accuracy: 2)
        XCTAssertTrue(tabs.buttons["tab-schedule"].isHittable)
        tabs.buttons["tab-toolbox"].tap()
        XCTAssertTrue(app.navigationBars["工具箱"].waitForExistence(timeout: 5))
        XCTAssertFalse(accessory.exists)
        let toolboxFrame = tabs.frame
        XCTAssertEqual(toolboxFrame.height, initialFrame.height, accuracy: 2)
        XCTAssertEqual(toolboxFrame.minY, initialFrame.minY, accuracy: 2)
        let toolboxAttachment = XCTAttachment(screenshot: app.screenshot())
        toolboxAttachment.name = legacy ? "toolbox-without-accessory-legacy" : "toolbox-without-accessory-modern"
        toolboxAttachment.lifetime = .keepAlways
        add(toolboxAttachment)
        app.buttons["考试考场"].tap()
        XCTAssertTrue(app.navigationBars["考试信息"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabs.waitForNonExistence(timeout: 5))
        app.navigationBars["考试信息"].buttons.firstMatch.tap()
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        XCTAssertFalse(accessory.exists)
        app.swipeUp()
        XCTAssertEqual(tabs.frame.height, toolboxFrame.height, accuracy: 2)
        XCTAssertEqual(tabs.frame.minY, toolboxFrame.minY, accuracy: 2)
        tabs.buttons["tab-home"].tap()
        XCTAssertTrue(app.navigationBars["今天"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabs.buttons["tab-settings"].isHittable)
        XCTAssertFalse(accessory.exists)
        tabs.buttons["tab-settings"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabs.buttons["tab-schedule"].isHittable)
        XCTAssertFalse(accessory.exists)
        tabs.buttons["tab-schedule"].tap()
        XCTAssertTrue(accessory.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = legacy ? "fixed-tabs-legacy" : "fixed-tabs-modern"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
