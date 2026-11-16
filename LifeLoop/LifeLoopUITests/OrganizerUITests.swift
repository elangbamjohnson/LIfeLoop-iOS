import XCTest

@MainActor
final class OrganizerUITests: XCTestCase {
    private let firstID = "item-00000000-0000-0000-0000-000000000001"
    private let secondID = "item-00000000-0000-0000-0000-000000000002"

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testCancelDiscardsDraftAndSaveUpdatesList() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
        openFirstItem(app)
        app.buttons["editItem"].tap()
        let field = app.descendants(matching: .any)["itemTitleField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        replaceText(in: field, with: "Pay electricity bill tomorrow", app: app)
        app.buttons["cancelItemEdit"].tap()
        assertDetail("Pay electricity bill", in: app)

        app.buttons["editItem"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Pay electricity bill")
        replaceText(in: field, with: "Pay electricity bill tomorrow", app: app)
        app.buttons["saveItemEdit"].tap()
        assertDetail("Pay electricity bill tomorrow", in: app)
        showList(app)
        XCTAssertTrue(app.descendants(matching: .any)[firstID].firstMatch.label.contains("tomorrow"))
        app.descendants(matching: .any)[secondID].firstMatch.tap()
        assertDetail("Renew car insurance", in: app)
    }

    func testDraftSurvivesRotationAndBlankTitleCannotSave() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
        openFirstItem(app)
        app.buttons["editItem"].tap()
        let field = app.descendants(matching: .any)["itemTitleField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        replaceText(in: field, with: "   ", app: app)
        XCTAssertFalse(app.buttons["saveItemEdit"].isEnabled)
        field.typeText("New title")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(field.value as? String, "   New title")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(field.value as? String, "   New title")
        app.buttons["saveItemEdit"].tap()
        assertDetail("New title", in: app)
    }

    func testEmptyAndFailureStates() {
        let app = XCUIApplication()
        app.launchArguments = ["--empty-items"]
        app.launchArguments.append("--ui-testing")
        app.launch()
        XCTAssertTrue(app.staticTexts["No items yet"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--failed-items"]
        app.launchArguments.append("--ui-testing")
        app.launch()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 5))
        app.buttons["Try again"].tap()
        XCTAssertTrue(app.staticTexts["Unable to load items"].waitForExistence(timeout: 5))
    }

    func testLargeTextEditorIsAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launchArguments.append("--ui-testing")
        app.launch()
        openFirstItem(app)
        app.buttons["editItem"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["itemTitleField"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cancelItemEdit"].isHittable)
        XCTAssertTrue(app.buttons["saveItemEdit"].isHittable)
        try app.performAccessibilityAudit(for: [.elementDetection, .sufficientElementDescription])
    }

    private func replaceText(in field: XCUIElement, with text: String, app: XCUIApplication) {
        field.tap()
        field.press(forDuration: 1.2)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
        } else {
            app.buttons["Select All"].tap()
        }
        field.typeText(text)
    }

    private func assertDetail(_ title: String, in app: XCUIApplication) {
        let detail = app.descendants(matching: .any)["itemDetail"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.label.contains(title), detail.label)
    }

    private func openFirstItem(_ app: XCUIApplication) {
        let row = app.descendants(matching: .any)[firstID].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["editItem"].waitForExistence(timeout: 5))
    }

    private func showList(_ app: XCUIApplication) {
        let row = app.descendants(matching: .any)[firstID].firstMatch
        if row.isHittable { return }
        let back = app.navigationBars.buttons["LifeLoop"]
        if back.exists { back.tap() }
        else { app.buttons["Show Sidebar"].tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
