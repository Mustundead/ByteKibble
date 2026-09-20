import XCTest

final class ByteKibbleUITests: XCTestCase {
    func testPhysicalCameraSessionCanReturnWithoutImport() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires an available physical camera")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-welcome.completed", "YES"]
        app.launch()
        app.buttons["添加订阅"].firstMatch.tap()
        app.buttons["扫描二维码"].tap()
        let guidance = app.staticTexts["对准二维码，轻点高亮的二维码填入链接。确认添加前不会保存或查询。"]
        guard guidance.waitForExistence(timeout: 8) else {
            app.navigationBars["扫描二维码"].buttons["取消"].tap()
            throw XCTSkip("Camera permission or availability requires user action; no permission was changed")
        }
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(guidance.waitForExistence(timeout: 8))
        app.navigationBars["扫描二维码"].buttons["取消"].tap()
        XCTAssertTrue(app.secureTextFields["HTTPS 订阅链接"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["添加"].isEnabled)
        capture("camera-cancel-empty-form")
        app.navigationBars.buttons["取消"].tap()
        #endif
    }
    func testSystemShareExtensionPresentation() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-welcome.completed", "YES", "--qa-share-presentation"]
        app.launch()
        let extensionButton = app.cells["ByteKibble"].firstMatch
        XCTAssertTrue(app.cells.matching(identifier: "shareCell").firstMatch.waitForExistence(timeout: 5))
        for _ in 0..<10 where !extensionButton.isHittable {
            if app.cells["More"].firstMatch.isHittable { app.cells["More"].firstMatch.tap(); break }
            guard let row = app.cells.matching(identifier: "shareCell").allElementsBoundByIndex.first(where: { $0.isHittable }) else { break }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.width * 0.9, dy: row.frame.midY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.width * 0.1, dy: row.frame.midY)))
        }
        capture("system-share-activity-picker")
        let moreListTitle = app.staticTexts.matching(identifier: "activityTitleLabel")
            .matching(NSPredicate(format: "label == %@", "ByteKibble")).firstMatch
        let target = extensionButton.exists ? extensionButton : moreListTitle
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        guard target.exists else { return }
        target.tap()
        let save = app.buttons["Save to ByteKibble"]
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        XCTAssertTrue(save.isEnabled)
        capture("system-share-extension")
        app.buttons["Cancel"].firstMatch.tap()
    }
    func testEmptyOverviewSyncRoutes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-welcome.completed", "YES"]
        app.launch()
        guard app.buttons["Sync with iCloud"].waitForExistence(timeout: 5) else {
            throw XCTSkip("Requires an empty local library; existing subscriptions are preserved")
        }
        app.buttons["Sync with iCloud"].tap()
        XCTAssertTrue(app.navigationBars["iCloud Sync"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Manual Transfer"].waitForExistence(timeout: 5))
        app.buttons["Manual Transfer"].tap()
        XCTAssertTrue(app.navigationBars["Manual Transfer"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Choose Encrypted File"].isEnabled)
        capture("empty-overview-manual-transfer")
    }
    func testWelcomeSyncRoutes() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-welcome.completed", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.sync"].waitForExistence(timeout: 5))
        app.buttons["welcome.sync"].tap()
        XCTAssertTrue(app.buttons["连接前需要什么"].waitForExistence(timeout: 5))
        app.buttons["连接前需要什么"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "同一 Apple 账户")).firstMatch.exists)
        capture("welcome-cloud-prerequisites")
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["welcome.transfer"].waitForExistence(timeout: 5))
        app.buttons["welcome.transfer"].tap()
        XCTAssertTrue(app.navigationBars["手动传输"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["选择加密文件"].isEnabled)
        capture("welcome-manual-fallback")
    }
    func testSettingsAccessibilityLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-AppleLanguages", "(en)", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.buttons["iCloud Sync"].waitForExistence(timeout: 5))
        capture("settings-accessibility-layout")
        app.buttons["iCloud Sync"].tap()
        XCTAssertTrue(app.buttons["Before You Connect"].waitForExistence(timeout: 5))
        app.buttons["Before You Connect"].tap()
        capture("sync-accessibility-layout")
    }
    func testGraphicalSettingsChinese() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-welcome.completed", "YES"]
        app.launch()
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.buttons["iCloud 同步"].waitForExistence(timeout: 5))
        capture("settings-graphical-chinese-device")
        app.buttons["iCloud 同步"].tap()
        XCTAssertTrue(app.buttons["连接前需要什么"].waitForExistence(timeout: 5))
        capture("sync-graphical-chinese-device")
        app.buttons["连接前需要什么"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "同一 Apple 账户")).firstMatch.exists)
    }
    func testSyncAndTransferEnglish() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-welcome.completed", "YES"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["iCloud Sync"].tap()
        XCTAssertTrue(app.navigationBars["iCloud Sync"].waitForExistence(timeout: 5))
        capture("sync-english-off")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Manual Transfer"].tap()
        XCTAssertTrue(app.navigationBars["Manual Transfer"].waitForExistence(timeout: 5))
        capture("manual-transfer-english")
        XCTAssertFalse(app.buttons["Choose Encrypted File"].isEnabled)
    }
    func testEnglishWelcomeAndSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-welcome.completed", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to ByteKibble"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Your First Subscription"].isHittable)
        XCTAssertTrue(app.buttons["Not Now"].isHittable)
        capture("welcome-english")
        app.swipeUp()
        XCTAssertTrue(app.buttons["Not Now"].isHittable)
        capture("welcome-english-scrolled")
        app.buttons["Not Now"].tap()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("settings-english")
    }
    func testHistoryChartRanges() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "演示订阅")).firstMatch.tap()
        let link = app.buttons["历史观测图"]
        for _ in 0..<5 where !link.isHittable { app.swipeUp() }
        link.tap()
        XCTAssertTrue(app.navigationBars["历史观测图"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["近 7 天"].isSelected)
        app.buttons["近 30 天"].tap()
        XCTAssertTrue(app.buttons["近 30 天"].isSelected)
        XCTAssertFalse(app.staticTexts["没有可绘制的读数"].exists)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "history-chart-accessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        capture("history-chart-30-days")
    }
    func testHistoryPreviewAndClear() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "演示订阅")).firstMatch.tap()
        let export = app.buttons["预览并导出 CSV"]
        for _ in 0..<5 where !export.isHittable { app.swipeUp() }
        export.tap()
        XCTAssertTrue(app.navigationBars["导出历史"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["存储 CSV 文件"].exists)
        capture("history-export-preview")
        app.buttons["存储 CSV 文件"].tap()
        XCTAssertTrue(app.buttons["保存"].waitForExistence(timeout: 5))
        capture("history-file-picker")
        let picker = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
        picker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        let pickerDismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: picker)
        wait(for: [pickerDismissed], timeout: 5)
        XCTAssertTrue(app.navigationBars["导出历史"].waitForExistence(timeout: 5))
        app.buttons["关闭"].tap()
        app.buttons["清空此订阅历史"].tap()
        app.buttons["取消"].tap()
        XCTAssertTrue(export.isEnabled)
        app.buttons["清空此订阅历史"].tap()
        app.buttons["清空历史"].tap()
        XCTAssertFalse(export.isEnabled)
        XCTAssertTrue(app.staticTexts["尚无历史读数，下次查询成功后开始记录"].exists)
        capture("history-cleared")
        let chart = app.buttons["历史观测图"]
        for _ in 0..<5 where !chart.isHittable { app.swipeDown() }
        chart.tap()
        XCTAssertTrue(app.staticTexts["没有可绘制的读数"].waitForExistence(timeout: 5))
        capture("history-chart-empty")
    }
    func testWelcomeAddAndReview() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-welcome.completed", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["欢迎使用 ByteKibble"].waitForExistence(timeout: 5))
        capture("welcome")
        let add = app.buttons["添加第一个订阅"]
        XCTAssertTrue(add.isHittable)
        XCTAssertGreaterThan(add.frame.midY, app.frame.height * 0.7)
        for _ in 0..<5 where !add.isHittable { app.swipeUp() }
        add.tap()
        XCTAssertTrue(app.secureTextFields["HTTPS 订阅链接"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["添加"].isEnabled)
        app.buttons["取消"].tap()
        app.tabBars.buttons["设置"].tap()
        let review = app.buttons["使用说明与隐私"]
        for _ in 0..<5 where !review.isHittable { app.swipeUp() }
        review.tap()
        XCTAssertTrue(app.staticTexts["欢迎使用 ByteKibble"].waitForExistence(timeout: 5))
        let done = app.buttons["完成"]
        for _ in 0..<5 where !done.isHittable { app.swipeUp() }
        done.tap()
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
    }
    func testWelcomeSkipIsRemembered() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-welcome.completed", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["欢迎使用 ByteKibble"].waitForExistence(timeout: 5))
        let skip = app.buttons["暂不添加"]
        for _ in 0..<5 where !skip.isHittable { app.swipeUp() }
        skip.tap()
        XCTAssertTrue(app.staticTexts["流量，心中有数"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["流量，心中有数"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["欢迎使用 ByteKibble"].exists)
    }
    func testCameraUnavailableCanReturnWithoutImport() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("This case verifies simulator camera unavailability, not physical camera permission or recognition")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-welcome.completed", "YES"]
        app.launch()
        app.buttons["添加订阅"].firstMatch.tap()
        app.buttons["扫描二维码"].tap()
        XCTAssertTrue(app.staticTexts["此设备不支持相机扫描。请返回，使用图片识别或粘贴订阅链接。"].waitForExistence(timeout: 5))
        capture("camera-unavailable")
        app.buttons["返回添加订阅"].tap()
        XCTAssertTrue(app.secureTextFields["HTTPS 订阅链接"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["添加"].isEnabled)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["流量，心中有数"].exists)
        #endif
    }
    func testReminderSettingsExplainLimits() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.staticTexts["小组件"].waitForExistence(timeout: 5))
        capture("settings-graphical-chinese")
        app.buttons["小组件与隐私"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "不包含订阅名称或链接")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["提醒与刷新"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["开启订阅提醒"].isEnabled)
        XCTAssertTrue(app.switches["尝试后台刷新"].exists)
        capture("reminder-settings")
    }
    func testDemoAndManualReset() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["演示数据 · 不会查询真实订阅"].waitForExistence(timeout: 10))
        capture("overview-light")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "演示订阅")).firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "设置日期")).firstMatch.waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "设置日期")).firstMatch.tap()
        app.buttons["保存"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "手动")).firstMatch.exists)
        capture("detail-reset")
    }
    func testInvalidImportDoesNotCreateSubscription() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-welcome.completed", "YES"]
        app.launch()
        app.buttons["添加订阅"].firstMatch.tap()
        let field = app.secureTextFields["HTTPS 订阅链接"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("http://example.com/sub")
        app.buttons["添加"].tap()
        XCTAssertTrue(app.staticTexts["importError"].waitForExistence(timeout: 5))
        capture("invalid-import")
        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["流量，心中有数"].exists)
    }
    private func capture(_ name: String) {
        // AX existence can precede the final composited navigation frame.
        let rendered = expectation(description: "Composited frame")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { rendered.fulfill() }
        wait(for: [rendered], timeout: 2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
