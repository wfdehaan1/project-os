import XCTest

@MainActor
final class ProjectOSUITests: XCTestCase {
    func testLaunchesLibrary() {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["ProjectOS"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["Create a new project"].exists, app.debugDescription)
    }

    func testOpeningConversationsAndTogglingProjectUpdatesKeepsWorkspaceAlive() {
        let app = launchApp()
        let createProject = app.buttons["Create a new project"]
        XCTAssertTrue(createProject.waitForExistence(timeout: 5), app.debugDescription)
        createProject.click()

        let projectName = "Conversation Navigation \(UUID().uuidString.prefix(8))"
        let projectNameField = app.textFields["Project name"]
        XCTAssertTrue(projectNameField.waitForExistence(timeout: 5), app.debugDescription)
        projectNameField.click()
        projectNameField.typeText(projectName)
        let createSheet = app.sheets.firstMatch
        XCTAssertTrue(createSheet.waitForExistence(timeout: 5), app.debugDescription)
        createSheet.buttons["Create"].click()

        let conversationSection = app.staticTexts["Conversation"].firstMatch
        XCTAssertTrue(conversationSection.waitForExistence(timeout: 5), app.debugDescription)
        conversationSection.click()

        let workspace = app.staticTexts["conversation.workspace-heading"]
        let projectUpdates = app.staticTexts["conversation.project-updates-heading"]
        let toggleProjectUpdates = app.buttons["conversation.toggle-project-updates"]
        XCTAssertTrue(workspace.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Conversations"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Start with your project"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.descendants(matching: .any)["Context Preview"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(projectUpdates.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(toggleProjectUpdates.exists, app.debugDescription)

        let window = app.windows.firstMatch
        let bottomRight = window.coordinate(withNormalizedOffset: CGVector(dx: 0.998, dy: 0.998))
        let minimumWidthTarget = window.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.998))
        bottomRight.press(forDuration: 0.1, thenDragTo: minimumWidthTarget)
        XCTAssertLessThanOrEqual(window.frame.width, 850, app.debugDescription)
        XCTAssertTrue(projectUpdates.waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["Close Project Updates"].click()
        XCTAssertTrue(projectUpdates.waitForNonExistence(timeout: 5), app.debugDescription)
        toggleProjectUpdates.click()
        XCTAssertTrue(projectUpdates.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(workspace.exists, app.debugDescription)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-ApplePersistenceIgnoreState", "YES"])
        app.launch()
        return app
    }
}
