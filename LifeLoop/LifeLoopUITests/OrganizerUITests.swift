import XCTest

@MainActor
final class OrganizerUITests: XCTestCase {
    private let firstID = "item-00000000-0000-0000-0000-000000000001"
    private let secondID = "item-00000000-0000-0000-0000-000000000002"

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
        try super.tearDownWithError()
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

        // 1. Verify Quick Capture FAB is present
        let quickCapture = app.buttons["quickCaptureButton"].firstMatch
        XCTAssertTrue(quickCapture.waitForExistence(timeout: 5))

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

    func testManualItemCreationFlow() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        let quickCapture = app.buttons["quickCaptureButton"].firstMatch
        XCTAssertTrue(quickCapture.waitForExistence(timeout: 5))
        quickCapture.tap()

        let createManually = app.buttons["openManualCreationButton"].firstMatch
        XCTAssertTrue(createManually.waitForExistence(timeout: 5))
        createManually.tap()

        let titleField = app.descendants(matching: .any)["createItemTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))

        // Verify Save is disabled when title is blank
        let saveButton = app.buttons["saveCreateItem"].firstMatch
        XCTAssertFalse(saveButton.isEnabled)

        // Cancel discards
        let cancelButton = app.buttons["cancelCreateItem"].firstMatch
        cancelButton.tap()
        XCTAssertTrue(quickCapture.waitForExistence(timeout: 5))

        // Open creation modal again via Quick Capture -> Create manually
        quickCapture.tap()
        XCTAssertTrue(createManually.waitForExistence(timeout: 5))
        createManually.tap()

        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Buy Organic Milk")
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        // Wait for sheet dismissal
        XCTAssertTrue(saveButton.waitForNonExistence(timeout: 8))

        // Verify newly created item is rendered (scroll Priority list if LazyVStack places UPCOMING below the fold)
        let createdItem = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Buy Organic Milk'")).firstMatch
        if !createdItem.waitForExistence(timeout: 5) {
            let list = app.scrollViews["priorityScrollView"]
            var attempts = 0
            while !createdItem.exists && attempts < 4 {
                if list.exists {
                    list.swipeUp()
                } else {
                    app.swipeUp()
                }
                attempts += 1
            }
        }
        XCTAssertTrue(createdItem.waitForExistence(timeout: 5))
    }

    func testQuickCaptureFlow() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()

        let quickCapture = app.buttons["quickCaptureButton"].firstMatch
        XCTAssertTrue(quickCapture.waitForExistence(timeout: 5))
        quickCapture.tap()

        let textInput = app.descendants(matching: .any)["captureTextInput"].firstMatch
        XCTAssertTrue(textInput.waitForExistence(timeout: 5))

        let saveButton = app.buttons["saveCaptureButton"].firstMatch
        XCTAssertFalse(saveButton.isEnabled)

        textInput.tap()
        textInput.typeText("Pay electricity bill tomorrow and renew car insurance")
        XCTAssertTrue(saveButton.isEnabled)

        saveButton.tap()
        _ = saveButton.waitForNonExistence(timeout: 5)

        let inboxTab = app.buttons["Inbox"].firstMatch
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 5))
        inboxTab.tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Recent Captures'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Pay electricity bill'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testInboxHistoryVisibleWithoutItemsAndWhenItemsFail() {
        let app = XCUIApplication()
        for itemState in ["--empty-items", "--failed-items"] {
            app.launchArguments = ["--ui-testing", itemState]
            app.launch()
            app.buttons["Inbox"].firstMatch.tap()
            let completed = app.descendants(matching: .any)["captureRow-10000000-0000-0000-0000-000000000001"].firstMatch
            let pending = app.descendants(matching: .any)["captureRow-10000000-0000-0000-0000-000000000002"].firstMatch
            XCTAssertTrue(completed.waitForExistence(timeout: 10))
            XCTAssertTrue(pending.exists)
            if itemState == "--failed-items" {
                XCTAssertTrue(app.buttons["Retry items"].waitForExistence(timeout: 5))
            }
            app.terminate()
        }
    }

    func testCaptureFailureRetainsExactDraftAndRetrySucceeds() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--empty-items", "--empty-captures", "--fail-first-capture"]
        app.launch()
        app.buttons["quickCaptureButton"].firstMatch.tap()
        let input = app.textViews["captureTextInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5), app.debugDescription)
        let draft = "Pay bill tomorrow\nand renew passport"
        input.tap()
        input.typeText(draft)
        let save = app.buttons["saveCaptureButton"]
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["captureErrorMessage"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, draft)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        app.buttons["Inbox"].firstMatch.tap()
        let capture = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'captureRow-' AND label CONTAINS %@", "Pay bill tomorrow")
        ).firstMatch
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        XCTAssertTrue(capture.label.contains("Pending"))
    }

    func testHistoryFailureKeepsReviewItemsAndRetryAvailable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--failed-captures"]
        app.launch()
        app.buttons["Inbox"].firstMatch.tap()
        let retry = app.buttons["retryCaptureHistory"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        let reviewItem = app.descendants(matching: .any)[secondID].firstMatch
        XCTAssertTrue(reviewItem.waitForExistence(timeout: 5))
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(reviewItem.exists)
    }

    func testEmptyInboxUsesEmptyCaptureFixture() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--empty-items", "--empty-captures"]
        app.launch()
        app.buttons["Inbox"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Captures and incoming items will appear here."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["captureRow-10000000-0000-0000-0000-000000000001"].exists)
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["Captures and incoming items will appear here."].waitForExistence(timeout: 5))
    }

    func testInboxCaptureReviewConfirmEditRetryAndDelete() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["Inbox"].firstMatch.tap()

        let completedCapture = app.descendants(matching: .any)["captureRow-10000000-0000-0000-0000-000000000001"].firstMatch
        XCTAssertTrue(completedCapture.waitForExistence(timeout: 10))

        let linkedItem = app.descendants(matching: .any)["captureItem-00000000-0000-0000-0000-000000000002"].firstMatch
        XCTAssertTrue(linkedItem.waitForExistence(timeout: 5))

        let editButton = app.buttons["captureEditItem-00000000-0000-0000-0000-000000000002"].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let titleField = app.descendants(matching: .any)["itemTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        replaceText(in: titleField, with: "Renew car insurance policy", app: app)
        let saveEditButton = app.buttons["saveItemEdit"].firstMatch
        saveEditButton.tap()
        _ = saveEditButton.waitForNonExistence(timeout: 5)

        let confirmButton = app.buttons["captureConfirmItem-00000000-0000-0000-0000-000000000002"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()
        XCTAssertTrue(confirmButton.waitForNonExistence(timeout: 5))

        let failedCapture = app.descendants(matching: .any)["captureRow-10000000-0000-0000-0000-000000000003"].firstMatch
        if !failedCapture.exists || !failedCapture.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(failedCapture.waitForExistence(timeout: 5))
        XCTAssertTrue(failedCapture.staticTexts["Saved (AI unavailable)"].waitForExistence(timeout: 5))

        let retryCapture = app.buttons["retryCapture-10000000-0000-0000-0000-000000000003"].firstMatch
        XCTAssertTrue(retryCapture.waitForExistence(timeout: 5))
        retryCapture.tap()

        XCTAssertTrue(retryCapture.waitForNonExistence(timeout: 5))
        XCTAssertTrue(failedCapture.staticTexts["Enriching with AI"].waitForExistence(timeout: 5))

        let deleteCapture = app.buttons["deleteCapture-10000000-0000-0000-0000-000000000003"].firstMatch
        XCTAssertTrue(deleteCapture.waitForExistence(timeout: 5))
        deleteCapture.tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'permanently removed'")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(failedCapture.waitForExistence(timeout: 5))

        deleteCapture.tap()
        let confirmDelete = app.buttons["confirmDeleteCapture"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()

        XCTAssertTrue(failedCapture.waitForNonExistence(timeout: 5))
    }

    func testCaptureActionFailurePreservesState() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fail-capture-action"]
        app.launch()

        app.buttons["Inbox"].firstMatch.tap()

        let failedCapture = app.descendants(matching: .any)["captureRow-10000000-0000-0000-0000-000000000003"].firstMatch
        if !failedCapture.exists || !failedCapture.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(failedCapture.waitForExistence(timeout: 10))

        let retryCapture = app.buttons["retryCapture-10000000-0000-0000-0000-000000000003"].firstMatch
        XCTAssertTrue(retryCapture.waitForExistence(timeout: 5))
        retryCapture.tap()

        let errorAlert = app.alerts["Action Failed"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5))
        errorAlert.buttons["OK"].tap()
        XCTAssertTrue(retryCapture.exists)

        let deleteCapture = app.buttons["deleteCapture-10000000-0000-0000-0000-000000000003"].firstMatch
        deleteCapture.tap()
        app.buttons["confirmDeleteCapture"].firstMatch.tap()

        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5))
        errorAlert.buttons["OK"].tap()
        XCTAssertTrue(failedCapture.exists)
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
        let timelineTab = app.buttons["Timeline"].firstMatch
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
