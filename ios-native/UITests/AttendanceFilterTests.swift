import XCTest

final class AttendanceFilterTests: XCTestCase {
    @MainActor
    func testAbnormalFilterShowsOnlyLateAndAbsentRecords() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GxuScreen", "c-attendance"]
        app.launch()

        func record(_ course: String, status: String) -> XCUIElement {
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", course, status)
            ).firstMatch
        }

        let recentNormal = record("高等数学", status: "正常")
        XCTAssertTrue(recentNormal.waitForExistence(timeout: 20))

        let picker = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label CONTAINS %@ OR value == %@", "筛选", "异常和最近 7 天", "异常和最近 7 天")
        ).firstMatch
        XCTAssertTrue(picker.exists)
        picker.tap()
        let onlyAbnormal = app.buttons["只看异常"]
        XCTAssertTrue(onlyAbnormal.waitForExistence(timeout: 5))
        onlyAbnormal.tap()

        XCTAssertTrue(recentNormal.waitForNonExistence(timeout: 5))
        XCTAssertFalse(record("程序设计基础", status: "正常").exists)
        XCTAssertFalse(record("体育", status: "正常").exists)
        XCTAssertTrue(record("大学英语", status: "迟到").exists)
        XCTAssertTrue(record("大学物理实验", status: "未到").exists)
        XCTAssertTrue(record("线性代数", status: "迟到").exists)
    }
}
