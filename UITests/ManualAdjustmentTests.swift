import XCTest

final class ManualAdjustmentTests: XCTestCase {
    @MainActor
    func testLocalLocationChangeCanBeRestoredFromCourseDetails() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "schedule", "-GxuScheduleSheet", "adjust"]
        app.launch()
        let location = app.descendants(matching: .any)["manual-adjustment-location"].firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 20), app.debugDescription)
        let editorPreview = XCTAttachment(screenshot: app.screenshot())
        editorPreview.name = "本地调课编辑页"
        editorPreview.lifetime = .keepAlways
        add(editorPreview)
        location.tap()
        location.typeText("本地测试教室")
        app.buttons["保存"].tap()
        let moved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "本地测试教室", "本地调整")).firstMatch
        XCTAssertTrue(moved.waitForExistence(timeout: 10))
        moved.tap()
        let edit = app.buttons["编辑本地调整"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let restore = app.buttons["恢复本次原安排"]
        if !restore.isHittable { app.swipeUp() }
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        app.buttons["恢复原安排"].tap()
        XCTAssertTrue(moved.waitForNonExistence(timeout: 10))
        app.terminate()
        app.launchArguments += ["-gxu.theme.appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["本地调课"].waitForExistence(timeout: 20))
        let accessiblePreview = XCTAttachment(screenshot: app.screenshot())
        accessiblePreview.name = "本地调课深色大字号"
        accessiblePreview.lifetime = .keepAlways
        add(accessiblePreview)
    }
}
