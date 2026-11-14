import XCTest

final class ScoreHistoryTests: XCTestCase {
    @MainActor
    func testAllTermsKeepsRetakesAndSupportsSearch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "toolbox", "-GxuOpen", "examScore"]
        app.launch()
        let term = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "选择学年和学期")).firstMatch
        XCTAssertTrue(term.waitForExistence(timeout: 20), app.debugDescription)
        term.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["全部学期"].waitForExistence(timeout: 5))
        app.buttons["全部学期"].tap()
        XCTAssertTrue(app.buttons["学术写作"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "高等数学").count, 2)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "未标明学期")).firstMatch.exists)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "全部学期成绩"
        preview.lifetime = .keepAlways
        add(preview)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("高等数学")
        XCTAssertTrue(app.buttons["学术写作"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "高等数学").count, 2)
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        search.typeText("教师甲")
        XCTAssertTrue(app.buttons["学术写作"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "高等数学").count, 1)
    }

    @MainActor
    func testHistoryInDarkLargeText() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GxuDemo", "-GxuTab", "toolbox", "-GxuOpen", "examScore",
                               "-gxu.theme.appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let term = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "选择学年和学期")).firstMatch
        XCTAssertTrue(term.waitForExistence(timeout: 20))
        term.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["全部学期"].waitForExistence(timeout: 5))
        app.buttons["全部学期"].tap()
        XCTAssertTrue(app.staticTexts["全部学期"].waitForExistence(timeout: 10))
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "全部学期深色大字号"
        preview.lifetime = .keepAlways
        add(preview)
    }

}
