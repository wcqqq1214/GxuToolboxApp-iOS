import XCTest

/// 真实后端的端到端走查：登录 → 课表 → 工具箱 → 考试 → 成绩（展开平时分）→ GPA → 设置 → 账号。
/// 由 `scripts/run-e2e-ui.sh` 驱动；账号经 TEST_RUNNER_GXU_TEST_USER/PASS 传入，截图写到 GXU_SHOT_DIR。
final class E2EWalkthroughTests: XCTestCase {
    var app: XCUIApplication!
    let shotDir = ProcessInfo.processInfo.environment["GXU_SHOT_DIR"]

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        let env = ProcessInfo.processInfo.environment
        app.launchEnvironment["GXU_TEST_USER"] = env["GXU_TEST_USER"]
        app.launchEnvironment["GXU_TEST_PASS"] = env["GXU_TEST_PASS"]
    }

    private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name; a.lifetime = .keepAlways
        add(a)
        if let dir = shotDir {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
    }

    private func tap(_ el: XCUIElement, _ what: String) {
        XCTAssertTrue(el.waitForExistence(timeout: 15), "找不到：\(what)")
        el.tap()
    }

    private func selectYear(_ text: String) {
        let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS '学年'")).firstMatch
        tap(picker, "学年选择器")
        let option = app.buttons[text].firstMatch
        if option.waitForExistence(timeout: 5) { option.tap() } else { XCTFail("没有学年选项 \(text)") }
    }

    func testWalkthrough() {
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))

        // 课表
        sleep(10)
        shot("01-schedule")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Cancellation'")).firstMatch.exists, "课表出现 CancellationError")

        // 工具箱
        tap(tabs.buttons["工具箱"], "工具箱标签")
        shot("02-toolbox")

        // 考试信息
        tap(app.buttons["考试信息"].firstMatch, "考试信息入口")
        sleep(3); shot("03-exam-default")
        selectYear("2025-2026 学年")
        sleep(5); shot("04-exam-2025")
        app.navigationBars.buttons.firstMatch.tap()

        // 成绩
        tap(app.buttons["成绩查询"].firstMatch, "成绩查询入口")
        sleep(3)
        selectYear("2025-2026 学年")
        sleep(5); shot("05-score-2025")
        let row = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '2025'")).element(boundBy: 2)
        if row.waitForExistence(timeout: 5) { row.tap(); sleep(5); shot("06-score-usual-expanded") } else { XCTFail("没有成绩行") }

        // GPA
        tap(app.navigationBars.buttons["绩点计算器"], "绩点计算器按钮")
        sleep(4); shot("07-gpa")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        // 设置 → 账号
        tap(tabs.buttons["设置"], "设置标签")
        shot("08-settings")
        tap(app.staticTexts["教务账号"].firstMatch, "教务账号入口")
        sleep(1); shot("09-account")
    }
}
