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
        if env["GXU_FORCE_LEGACY"] == "1" { app.launchArguments += ["-GxuForceLegacy"] }   // 强制走 iOS 18 的降级（Material）路径
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

    // MARK: Phase 2 / Phase 3 公共

    private var report: [String] = []

    private func note(_ line: String) {
        report.append(line)
        if let dir = shotDir {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? report.joined(separator: "\n").write(toFile: "\(dir)/\(reportName)", atomically: true, encoding: .utf8)
        }
    }

    private var reportName = "phase2-report.txt"

    /// 当前页面不允许出现的文字（见 Packages/GxuDesign/README.md 的页面文字规则：如「8 号座」或「……学年第一学期」类说明）
    private func scanText(_ screen: String) {
        let labels = app.staticTexts.allElementsBoundByIndex.prefix(150).map { $0.label }
        for label in labels {
            if label.contains("号座") { note("违反规则2  \(screen)：出现「\(label)」") }
            if label.range(of: "学年第[一二]学期", options: .regularExpression) != nil { note("违反规则9  \(screen)：出现「\(label)」") }
        }
    }

    /// 按名称找入口：先精确匹配按钮 / 文字，再匹配标签里包含该名称的按钮（卡片的无障碍标签可能带有附加文字）。
    /// 只认当前能点到的元素（`isHittable`），所以被浮动标签栏盖住或在屏幕外的入口要先滚动出来。
    private func find(_ aliases: [String]) -> XCUIElement? {
        for title in aliases {
            let queries = [
                app.buttons.matching(NSPredicate(format: "label == %@ OR identifier == %@", title, title)),
                app.staticTexts.matching(NSPredicate(format: "label == %@", title)),
                app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)),
            ]
            for query in queries {
                for element in query.allElementsBoundByIndex.prefix(8) where element.exists && element.isHittable {
                    return element
                }
            }
        }
        return nil
    }

    /// 打开一个入口（`aliases` 是新旧名称，按顺序找），截图，返回；找不到入口或没有进入新页面只记录，不算失败
    private func visit(_ aliases: [String], shot name: String, wait: UInt32 = 4, expectedHidden: Bool = false, rootTab: String? = nil) {
        let title = aliases[0]
        var entry = find(aliases)
        for _ in 0..<3 where entry == nil { app.swipeUp(); sleep(1); entry = find(aliases) }
        guard let entry else { note(expectedHidden ? "隐藏（预期）  \(title)" : "缺失  \(title)：页面上找不到入口"); return }
        if expectedHidden { note("未通过  \(title) 应该隐藏，但仍有入口") }
        entry.tap()
        sleep(wait)
        // 入口可能只是切换了标签（例如工具箱里的「课表」），这时不能去点导航栏按钮（课表页左上角是「+」）
        var switchedTab = false
        if let rootTab, app.tabBars.firstMatch.exists { switchedTab = !app.tabBars.buttons[rootTab].isSelected }
        let pushed = !switchedTab && app.navigationBars.buttons.firstMatch.exists   // 推入新页面后导航栏左侧才有返回按钮
        shot(name)
        if switchedTab {
            note("上线  \(title)（切换到对应标签）")
            scanText(title)
        } else if pushed {
            note("上线  \(title)")
            scanText(title)
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
        } else {
            note("未上线  \(title)：点击后没有进入新页面（多半是「即将上线」）")
        }
        // 有的入口（例如工具箱里的「课表」）是切换标签而不是推入页面：回到出发的标签再继续
        if let rootTab, app.tabBars.firstMatch.exists {
            app.tabBars.buttons[rootTab].tap()
            sleep(1)
        }
    }

    private func settingsEntries(_ titles: [[String]], prefix: String) {
        for (index, aliases) in titles.enumerated() {
            visit(aliases, shot: String(format: "%@-%02d", prefix, index + 1), wait: 6, rootTab: "设置")
        }
    }

    func testPhase2() {
        reportName = "phase2-report.txt"
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        sleep(10)
        shot("p2-01-home")
        note("首页：见 p2-01-home.png")

        tap(tabs.buttons["工具箱"], "工具箱标签")
        shot("p2-02-toolbox")
        // 新旧名称都认（B 把工具箱重排成 RN 的名称之后，旧名称找不到会自动用新名称）
        let entries: [[String]] = [
            ["考试考场", "考试信息"], ["考试成绩", "成绩查询"], ["GPA 计算"], ["已选课程"], ["校选课查漏", "选课策略"], ["调休信息", "调休补班"],
            ["调课信息", "调课通知"], ["期末学生评价", "教学评价"], ["班级课表"], ["全校实时课表", "全校课表"], ["地图导航", "校园地图"],
            ["物理实验课", "实践课"], ["金工实训"], ["法定节假日", "节假日"], ["教师信息查询", "教师查询"], ["考勤信息", "考勤查询"],
            ["学校文件", "OA 文件"], ["教学楼平面图"],
        ]
        for (index, aliases) in entries.enumerated() { visit(aliases, shot: String(format: "p2-03-toolbox-%02d", index + 1), rootTab: "工具箱") }
        note(app.buttons["空教室"].exists ? "未通过  工具箱里仍有「空教室」" : "通过  工具箱已删除「空教室」")

        tap(tabs.buttons["设置"], "设置标签")
        shot("p2-04-settings")
        settingsEntries([["个人信息"], ["统一认证账号"], ["考勤账号"], ["意见反馈"]], prefix: "p2-05-settings")
        if let entry = find(["意见反馈"]) {
            entry.tap(); sleep(2)
            note(app.buttons["我的反馈"].exists ? "未通过  意见反馈页仍显示「我的反馈」入口" : "通过  意见反馈页已隐藏「我的反馈」入口")
            shot("p2-06-feedback-form")
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        }
    }

    /// Phase 3 验收：工具箱按 RN `ToolboxIndex.tsx` 的分组和名称；隐藏项、范围外项；设置里 A 的新页面；各页面文字规则扫描
    func testPhase3() {
        reportName = "phase3-report.txt"
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        sleep(10)
        shot("p3-01-today")
        tap(tabs.buttons["课表"], "课表标签")
        sleep(5)
        shot("p3-02-schedule")                      // 规则 3/4/6/8：纯底色课程块、教室教师小一号、时间列上下课、标题居中
        scanText("课表")

        tap(tabs.buttons["工具箱"], "工具箱标签")
        shot("p3-03-toolbox")
        for group in ["信息查询", "实践课", "通知", "教学评价", "其他"] {
            var found = app.staticTexts[group].firstMatch.exists
            for _ in 0..<3 where !found { app.swipeUp(); found = app.staticTexts[group].firstMatch.exists }
            note(found ? "通过  工具箱分组「\(group)」" : "未通过  工具箱缺少分组「\(group)」（RN ToolboxIndex）")
        }
        app.swipeDown(); app.swipeDown()
        let entries: [([String], Bool)] = [
            (["课表"], false), (["班级课表"], false), (["导出课表"], false), (["考试考场"], false), (["考试成绩"], false), (["考勤信息"], false),
            (["选课课程列表"], true), (["校选课查漏"], false), (["教师查询"], false),
            (["物理实验课"], false), (["金工实训"], false),
            (["调课信息"], true), (["调休信息"], false), (["法定节假日"], false), (["学校文件"], false),
            (["期末学生评价"], false),
            (["地图导航"], false), (["全校实时课表"], false), (["教学楼平面图"], false),
        ]
        for (index, entry) in entries.enumerated() {
            // 「课表」「导出课表」会和标签栏 / 其他文字重名，只在工具箱页内找按钮
            visit(entry.0, shot: String(format: "p3-04-toolbox-%02d", index + 1), wait: 5, expectedHidden: entry.1, rootTab: "工具箱")
        }
        // 不该出现的入口
        for removed in ["校园网充值", "空教室", "已选课程", "GPA 计算"] {
            note(find([removed]) != nil ? "未通过  工具箱里不应该有「\(removed)」" : "通过  工具箱没有「\(removed)」")
        }

        tap(tabs.buttons["设置"], "设置标签")
        shot("p3-05-settings")
        settingsEntries([["个人信息"], ["统一认证账号"], ["考勤账号"], ["OA 账号"], ["意见反馈"], ["诊断日志"]], prefix: "p3-06-settings")
    }
}
