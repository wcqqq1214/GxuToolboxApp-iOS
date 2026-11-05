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

    // MARK: Phase 2

    private var report: [String] = []

    private func note(_ line: String) {
        report.append(line)
        if let dir = shotDir {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? report.joined(separator: "\n").write(toFile: "\(dir)/phase2-report.txt", atomically: true, encoding: .utf8)
        }
    }

    /// 打开一个入口，截图，返回；入口不存在或点进去没有导航（即将上线）只记录，不算失败
    private func visit(_ title: String, shot name: String, wait: UInt32 = 4, scrollingIn container: XCUIElement? = nil) {
        func find() -> XCUIElement { app.buttons[title].firstMatch.exists ? app.buttons[title].firstMatch : app.staticTexts[title].firstMatch }
        var entry = find()
        for _ in 0..<3 where !entry.waitForExistence(timeout: 3) { app.swipeUp(); entry = find() }   // 入口可能在屏幕下方
        if !entry.exists { note("缺失  \(title)：页面上找不到入口"); return }
        entry.tap()
        sleep(wait)
        let pushed = app.navigationBars.buttons.firstMatch.exists   // 推入新页面后导航栏左侧才有返回按钮
        shot(name)
        if pushed {
            note("上线  \(title)")
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
        } else {
            note("未上线  \(title)：点击后没有进入新页面（多半是「即将上线」）")
        }
    }

    func testPhase2() {
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        sleep(10)
        shot("p2-01-home")                                   // 课表 / 首页（含下一节课附件、节假日 / 调课叠加）
        note("首页：见 p2-01-home.png")

        tap(tabs.buttons["工具箱"], "工具箱标签")
        shot("p2-02-toolbox")
        let titles = ["已选课程", "选课策略", "调课通知", "教学评价", "班级课表", "全校课表", "校园地图", "实践课", "节假日", "教师查询", "考勤查询", "校园网充值", "OA 文件"]
        for (index, title) in titles.enumerated() {
            visit(title, shot: String(format: "p2-03-toolbox-%02d", index + 1))
        }
        note(app.buttons["空教室"].exists ? "未通过  工具箱里仍有「空教室」" : "通过  工具箱已删除「空教室」")

        // 设置里的 A 的页面
        tap(tabs.buttons["设置"], "设置标签")
        shot("p2-04-settings")
        for (index, title) in ["个人信息", "统一认证账号", "考勤账号", "意见反馈"].enumerated() {
            visit(title, shot: String(format: "p2-05-settings-%02d", index + 1), wait: 6)
            if title == "意见反馈" {
                // 我的反馈入口应已隐藏；这里在页面内检查，所以重新进入一次
                var entry = app.staticTexts[title].firstMatch.exists ? app.staticTexts[title].firstMatch : app.buttons[title].firstMatch
                for _ in 0..<3 where !entry.exists { app.swipeUp(); entry = app.staticTexts[title].firstMatch }
                if entry.exists {
                    entry.tap(); sleep(2)
                    note(app.buttons["我的反馈"].exists ? "未通过  意见反馈页仍显示「我的反馈」入口" : "通过  意见反馈页已隐藏「我的反馈」入口")
                    shot("p2-06-feedback-form")
                    if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
                }
            }
        }
    }
}
