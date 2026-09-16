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
        createProject(in: app, named: "Conversation Navigation")

        // The sidebar destinations are buttons addressed by a stable identifier.
        let conversationDestination = app.buttons["sidebar.conversation"]
        XCTAssertTrue(conversationDestination.waitForExistence(timeout: 5), app.debugDescription)
        conversationDestination.click()

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

    /// Empty destinations used to demand a window thousands of points tall,
    /// which pushed the sidebar's top and bottom outside the window.
    func testSidebarStaysInsideWindowOnEmptyDestinations() {
        let app = launchApp()
        createProject(in: app, named: "Sidebar Layout")
        let window = app.windows.firstMatch

        for identifier in ["sidebar.sources", "sidebar.changeLog"] {
            let destination = app.buttons[identifier]
            XCTAssertTrue(destination.waitForExistence(timeout: 5), app.debugDescription)
            destination.click()

            let firstRow = app.buttons["sidebar.overview"]
            let allProjects = app.buttons["All Projects"].firstMatch
            XCTAssertTrue(firstRow.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertGreaterThanOrEqual(firstRow.frame.minY, window.frame.minY, "\(identifier): sidebar top is above the window")
            XCTAssertLessThanOrEqual(allProjects.frame.maxY, window.frame.maxY, "\(identifier): sidebar bottom is below the window")
        }
    }

    /// Settings is global rather than per-project, so it has to be reachable
    /// from the Project Library without opening a project first.
    func testLibrarySettingsIsReachableAndOffersTheme() {
        let app = launchApp()

        let settings = app.buttons["library.sidebar.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), app.debugDescription)
        settings.click()

        XCTAssertTrue(
            app.staticTexts["library.settings-heading"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.theme"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        // The projects themselves stay one click away.
        let projects = app.buttons["library.sidebar.projects"]
        XCTAssertTrue(projects.exists, app.debugDescription)

        // A row's selection marker is vertically flexible, so rows handed a
        // share of the sidebar's height stretch to fill it. They must stay the
        // height of their own content.
        let window = app.windows.firstMatch
        XCTAssertLessThan(settings.frame.height, 44, app.debugDescription)
        XCTAssertLessThan(projects.frame.height, 44, app.debugDescription)
        XCTAssertLessThan(projects.frame.height, window.frame.height / 3, app.debugDescription)

        projects.click()
        XCTAssertTrue(
            app.buttons["Create a new project"].waitForExistence(timeout: 5),
            app.debugDescription
        )
    }

    /// New Project — from the switcher menu or ⌘N — sets one flag, and the sheet
    /// answering it used to exist only on the Project Library. Neither did
    /// anything while a project was open.
    func testNewProjectIsReachableWhileAProjectIsOpen() {
        let app = launchApp()
        createProject(in: app, named: "Switcher Create")

        // The workspace is open, so the Project Library is no longer on screen.
        XCTAssertTrue(app.buttons["sidebar.overview"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace.project-switcher"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        // Drive the switcher's own menu, which is where New Project now lives.
        // The identifier resolves to both the menu and its inner button, so the
        // outermost match is the one to press.
        app.descendants(matching: .any)["workspace.project-switcher"].firstMatch.click()
        // Scoped to the open popup, since the File menu carries the same title.
        let newProject = app.menus.menuItems["New Project"].firstMatch
        XCTAssertTrue(newProject.waitForExistence(timeout: 5), app.debugDescription)
        newProject.click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.textFields["Project name"].waitForExistence(timeout: 5), app.debugDescription)
        sheet.buttons["Cancel"].click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    private func createProject(in app: XCUIApplication, named prefix: String) {
        let createProject = app.buttons["Create a new project"]
        XCTAssertTrue(createProject.waitForExistence(timeout: 5), app.debugDescription)
        createProject.click()

        let projectNameField = app.textFields["Project name"]
        XCTAssertTrue(projectNameField.waitForExistence(timeout: 5), app.debugDescription)
        projectNameField.click()
        projectNameField.typeText("\(prefix) \(UUID().uuidString.prefix(8))")
        let createSheet = app.sheets.firstMatch
        XCTAssertTrue(createSheet.waitForExistence(timeout: 5), app.debugDescription)
        createSheet.buttons["Create"].click()
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-ApplePersistenceIgnoreState", "YES"])
        app.launch()
        return app
    }
}
