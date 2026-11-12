import XCTest

@MainActor
final class TabChromeTests: XCTestCase {
    func testFixedNativeTabBarAndScheduleOnlyAccessory() {
        verifyTabChrome(legacy: false)
    }

    func testLegacyNativeTabBarAndScheduleOnlyAccessory() {
        verifyTabChrome(legacy: true)
    }

    private func verifyTabChrome(legacy: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "schedule", "-GxuPickEvent", "holiday"]
        if legacy { app.launchArguments += ["-GxuForceLegacy"] }
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        let accessory = app.descendants(matching: .any).matching(identifier: "next-event-accessory").firstMatch
        XCTAssertTrue(accessory.waitForExistence(timeout: 20))
        let initialFrame = tabs.frame
        app.swipeUp()
        app.swipeUp()
        XCTAssertEqual(tabs.frame.height, initialFrame.height, accuracy: 2)
        XCTAssertEqual(tabs.frame.minY, initialFrame.minY, accuracy: 2)
        XCTAssertTrue(tabs.buttons["课表"].isHittable)
        tabs.buttons["工具箱"].tap()
        XCTAssertTrue(app.navigationBars["工具箱"].waitForExistence(timeout: 5))
        XCTAssertFalse(accessory.exists)
        app.swipeUp()
        XCTAssertEqual(tabs.frame.height, initialFrame.height, accuracy: 2)
        XCTAssertEqual(tabs.frame.minY, initialFrame.minY, accuracy: 2)
        app.swipeDown()
        app.buttons["考试考场"].tap()
        XCTAssertTrue(app.navigationBars["考试信息"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabs.waitForNonExistence(timeout: 5))
        app.navigationBars["考试信息"].buttons.firstMatch.tap()
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        tabs.buttons["今天"].tap()
        XCTAssertTrue(app.navigationBars["今天"].waitForExistence(timeout: 5))
        XCTAssertFalse(accessory.exists)
        tabs.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertFalse(accessory.exists)
        tabs.buttons["课表"].tap()
        XCTAssertTrue(accessory.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = legacy ? "fixed-tabs-legacy" : "fixed-tabs-modern"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
