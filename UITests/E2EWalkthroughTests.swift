import XCTest

final class E2EWalkthroughTests: XCTestCase {
    var app: XCUIApplication!
    let shotDir = ProcessInfo.processInfo.environment["GXU_SHOT_DIR"]

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        let env = ProcessInfo.processInfo.environment
        app.launchEnvironment["GXU_TEST_USER"] = env["GXU_TEST_USER"]
        app.launchEnvironment["GXU_TEST_PASS"] = env["GXU_TEST_PASS"]
        if env["GXU_FORCE_LEGACY"] == "1" { app.launchArguments += ["-GxuForceLegacy"] }
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

    func testPublicFeedbackAndExamSheetDemo() {
        app.launchArguments += ["-GxuDemo", "-GxuTab", "schedule", "-GxuScheduleSheet", "exam"]
        app.launch()
        XCTAssertTrue(app.navigationBars["考试"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["期末考试"].exists)
        shot("demo-exam")
        tap(app.buttons["复制考试信息"], "复制考试信息")
        XCTAssertTrue(app.buttons["已复制考试信息"].waitForExistence(timeout: 5))
        tap(app.buttons["完成"], "关闭考试")
        tap(app.tabBars.buttons["设置"], "设置")
        app.swipeUp()
        tap(app.buttons["意见反馈"], "意见反馈")
        tap(app.buttons["全部反馈"], "全部反馈")
        XCTAssertTrue(app.staticTexts["演示反馈：希望考试详情可以复制。"].waitForExistence(timeout: 10))
        shot("demo-feedback-list")
        tap(app.staticTexts["演示反馈：希望考试详情可以复制。"], "反馈详情")
        XCTAssertTrue(app.staticTexts["20******01"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["演示回复：已支持复制考试信息。"].exists)
        shot("demo-feedback-detail")
    }

    func testScheduleExamsScoresAndAcademicAccount() {
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))

        sleep(10)
        shot("01-schedule")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Cancellation'")).firstMatch.exists, "课表出现 CancellationError")

        tap(tabs.buttons["工具箱"], "工具箱标签")
        shot("02-toolbox")

        tap(app.buttons["考试信息"].firstMatch, "考试信息入口")
        sleep(3); shot("03-exam-default")
        selectYear("2025-2026 学年")
        sleep(5); shot("04-exam-2025")
        app.navigationBars.buttons.firstMatch.tap()

        tap(app.buttons["成绩查询"].firstMatch, "成绩查询入口")
        sleep(3)
        selectYear("2025-2026 学年")
        sleep(5); shot("05-score-2025")
        let row = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '2025'")).element(boundBy: 2)
        if row.waitForExistence(timeout: 5) { row.tap(); sleep(5); shot("06-score-usual-expanded") } else { XCTFail("没有成绩行") }

        tap(app.navigationBars.buttons["绩点计算器"], "绩点计算器按钮")
        sleep(4); shot("07-gpa")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        tap(tabs.buttons["设置"], "设置标签")
        shot("08-settings")
        tap(app.staticTexts["教务账号"].firstMatch, "教务账号入口")
        sleep(1); shot("09-account")
    }


    private var report: [String] = []

    private func note(_ line: String) {
        report.append(line)
        if let dir = shotDir {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? report.joined(separator: "\n").write(toFile: "\(dir)/\(reportName)", atomically: true, encoding: .utf8)
        }
    }

    private var reportName = "phase2-report.txt"

    private func scanText(_ screen: String) {
        let labels = app.staticTexts.allElementsBoundByIndex.prefix(150).map { $0.label }
        for label in labels {
            if label.contains("号座") { note("违反规则2  \(screen)：出现「\(label)」") }
            if label.range(of: "学年第[一二]学期", options: .regularExpression) != nil { note("违反规则9  \(screen)：出现「\(label)」") }
        }
    }

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

    private func visit(_ aliases: [String], shot name: String, wait: UInt32 = 4, expectedHidden: Bool = false, rootTab: String? = nil) {
        let title = aliases[0]
        var entry = find(aliases)
        for _ in 0..<3 where entry == nil { app.swipeUp(); sleep(1); entry = find(aliases) }
        guard let entry else { note(expectedHidden ? "隐藏（预期）  \(title)" : "缺失  \(title)：页面上找不到入口"); return }
        if expectedHidden { note("未通过  \(title) 应该隐藏，但仍有入口") }
        entry.tap()
        sleep(wait)
        var switchedTab = false
        if let rootTab, app.tabBars.firstMatch.exists { switchedTab = !app.tabBars.buttons[rootTab].isSelected }
        let pushed = !switchedTab && app.navigationBars.buttons.firstMatch.exists
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

    func testToolboxEntriesAndSettingsPages() {
        reportName = "phase2-report.txt"
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        sleep(10)
        shot("p2-01-home")
        note("首页：见 p2-01-home.png")

        tap(tabs.buttons["工具箱"], "工具箱标签")
        shot("p2-02-toolbox")
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
            note(app.buttons["全部反馈"].exists ? "通过  意见反馈页显示「全部反馈」入口" : "未通过  意见反馈页缺少「全部反馈」入口")
            shot("p2-06-feedback-form")
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        }
    }

    func testScheduleToolboxGroupsAndHiddenEntries() {
        reportName = "phase3-report.txt"
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        sleep(10)
        shot("p3-01-today")
        tap(tabs.buttons["课表"], "课表标签")
        sleep(5)
        shot("p3-02-schedule")
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
            visit(entry.0, shot: String(format: "p3-04-toolbox-%02d", index + 1), wait: 5, expectedHidden: entry.1, rootTab: "工具箱")
        }
        for removed in ["校园网充值", "空教室", "已选课程", "GPA 计算"] {
            note(find([removed]) != nil ? "未通过  工具箱里不应该有「\(removed)」" : "通过  工具箱没有「\(removed)」")
        }

        tap(tabs.buttons["设置"], "设置标签")
        shot("p3-05-settings")
        settingsEntries([["个人信息"], ["统一认证账号"], ["考勤账号"], ["OA 账号"], ["意见反馈"], ["诊断日志"]], prefix: "p3-06-settings")
    }
}
