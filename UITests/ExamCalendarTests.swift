import XCTest

final class ExamCalendarTests: XCTestCase {
    @MainActor
    func testExamListOpensCalendarEditorAndCancelKeepsExam() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "toolbox", "-GxuOpen", "examInfo"]
        app.launch()
        let exam = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "高等数学")).firstMatch
        XCTAssertTrue(exam.waitForExistence(timeout: 20))
        exam.tap()
        let add = app.buttons["添加到日历"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let title = app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", "高等数学 · 考试")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 60))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "考试系统日历编辑页"
        screenshot.lifetime = .keepAlways
        self.add(screenshot)
        let cancel = app.buttons.matching(NSPredicate(format: "label == '取消' OR label == 'Cancel'")).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertTrue(add.isEnabled)
        XCTAssertFalse(app.buttons["已添加到日历"].exists)
    }

    @MainActor
    func testSavingExamReturnsWithSuccessState() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "toolbox", "-GxuOpen", "examInfo"]
        app.launch()
        let exam = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "高等数学")).firstMatch
        XCTAssertTrue(exam.waitForExistence(timeout: 20))
        exam.tap()
        let add = app.buttons["添加到日历"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let title = app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", "高等数学 · 考试")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 60))
        app.buttons["add-button"].tap()
        let saved = app.buttons["已添加到日历"]
        XCTAssertTrue(saved.waitForExistence(timeout: 15))
        XCTAssertFalse(saved.isEnabled)
        XCTAssertFalse(app.buttons["add-button"].exists)
    }

    @MainActor
    func testScheduleExamDetailInDarkLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "schedule", "-GxuScheduleSheet", "exam", "-gxu.theme.appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let add = app.buttons["添加到日历"]
        for _ in 0..<5 {
            if add.waitForExistence(timeout: 3), add.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(add.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "考试日历入口深色大字号"
        screenshot.lifetime = .keepAlways
        self.add(screenshot)
    }
}
