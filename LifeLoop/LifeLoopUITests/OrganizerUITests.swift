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
        let saveBtn = app.buttons["saveItemEdit"]
        saveBtn.tap()
        _ = saveBtn.waitForNonExistence(timeout: 3)
        assertDetail("Pay electricity bill tomorrow", in: app)
        showList(app)
        XCTAssertTrue(app.descendants(matching: .any)[firstID].firstMatch.label.contains("tomorrow"))
        let secondRow = app.descendants(matching: .any)[secondID].firstMatch
        XCTAssertTrue(secondRow.waitForExistence(timeout: 5))
        secondRow.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
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

    func testPriorityTabComponentsAndWaitingForActions() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        // 1. Verify Quick Capture FAB is gated and hidden until F1.2
        XCTAssertFalse(app.buttons["quickCaptureButton"].exists)

        // 2. Verify Section Headers
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'REMINDERS & DUE TODAY'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'NEEDS ATTENTION'")).firstMatch.waitForExistence(timeout: 5))

        // Scroll down to expose Today and Waiting For sections
        let list = app.scrollViews["priorityScrollView"]
        if list.exists {
            list.swipeUp()
        } else {
            app.swipeUp()
        }

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'TODAY'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Nothing due today'")).firstMatch.waitForExistence(timeout: 5))

        // 3. Scroll to and verify Waiting For Section
        let waitingItem = app.descendants(matching: .any)["item-00000000-0000-0000-0000-000000000007"]
        var attempts = 0
        while !waitingItem.isHittable && attempts < 5 {
            if list.exists {
                list.swipeUp()
            } else {
                app.swipeUp()
            }
            attempts += 1
        }
        XCTAssertTrue(waitingItem.waitForExistence(timeout: 5))

        let waitingChevron = app.buttons["chevronExpand-00000000-0000-0000-0000-000000000007"]
        XCTAssertTrue(waitingChevron.waitForExistence(timeout: 5))

        // 4. Tap expand chevron to view waiting_for expanded actions
        waitingChevron.tap()

        // 5. Verify the 3 consistent buttons in Waiting For: Received, Remind me later, Follow up
        let receivedBtn = app.buttons["receivedItem-00000000-0000-0000-0000-000000000007"]
        let remindBtn = app.buttons["remindLaterItem-00000000-0000-0000-0000-000000000007"]
        let followUpBtn = app.buttons["followUpItem-00000000-0000-0000-0000-000000000007"]

        XCTAssertTrue(receivedBtn.waitForExistence(timeout: 3))
        XCTAssertTrue(remindBtn.waitForExistence(timeout: 3))
        XCTAssertTrue(followUpBtn.waitForExistence(timeout: 3))
    }

    func testPriorityExpansionSurvivesScrollingAndSwipesExposeActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let scroll = app.scrollViews["priorityScrollView"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        let row = app.descendants(matching: .any)[firstID].firstMatch
        let chevron = app.buttons["chevronExpand-00000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(chevron.waitForExistence(timeout: 5))
        chevron.tap()
        XCTAssertEqual(chevron.label, "Collapse item")
        scroll.swipeUp()
        scroll.swipeDown()
        XCTAssertEqual(chevron.label, "Collapse item")
        chevron.tap()
        XCTAssertEqual(chevron.label, "Expand item")

        // 1. Horizontal swipe left exposes actions and does not open detail page
        row.swipeLeft()
        XCTAssertFalse(app.buttons["editItem"].exists, "Swipe left should not open detail page")
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))

        // 2. Tapping the swiped card closes the actions and does not open detail page
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["editItem"].exists, "Tapping card should not open detail page")
        _ = app.buttons["Delete"].waitForNonExistence(timeout: 3)

        // 3. Tapping the resting card does not open detail page
        row.tap()
        XCTAssertFalse(app.buttons["editItem"].exists, "Tapping card should not open detail page")
    }

    func testPriorityContextMenuAndSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let row = app.descendants(matching: .any)[firstID].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Complete"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Snooze"].exists)
        XCTAssertTrue(app.buttons["Delete"].exists)
        app.tap()
        openFirstItem(app)
        assertDetail("Pay electricity bill", in: app)
        showList(app)
        let priorityTab = app.buttons["Priority"]
        if priorityTab.waitForExistence(timeout: 3) {
            priorityTab.tap()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.isSelected)
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
        let predicate = NSPredicate(format: "identifier == 'itemDetail' AND label CONTAINS[c] %@", title)
        let detail = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Expected itemDetail to contain '\(title)'")
    }

    private func openFirstItem(_ app: XCUIApplication) {
        let timelineTab = app.buttons["Timeline"]
        if timelineTab.waitForExistence(timeout: 3) {
            timelineTab.tap()
        }
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
