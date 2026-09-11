import XCTest

@MainActor
final class ProjectOSUITests: XCTestCase {
    func testLaunchesLibrary() {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-ApplePersistenceIgnoreState", "YES"])
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["ProjectOS"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["Create a new project"].exists, app.debugDescription)
    }
}
