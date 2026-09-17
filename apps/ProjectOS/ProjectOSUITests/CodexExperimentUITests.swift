import XCTest

@MainActor
final class CodexExperimentUITests: XCTestCase {
    func testNativeFixtureChatContextAndProposal() {
        let app = XCUIApplication()
        app.launchArguments = ["--codex-experiment", "--codex-experiment-fixture"]
        // Test runs use a separate file in the sandbox's temporary directory via an explicit fixture launch.
        app.launch()
        XCTAssertTrue(app.staticTexts["codex.heading"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["DETERMINISTIC UI FIXTURE — no live Codex connection"].exists)
        let send = app.buttons["codex.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 10))
        XCTAssertTrue(send.isEnabled)
        send.click()
        let answer = app.staticTexts["codex.assistant-message"].firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["codex.activity"].firstMatch.waitForExistence(timeout: 10) || app.descendants(matching: .any)["codex.activity"].firstMatch.exists)
        XCTAssertTrue(app.buttons["codex.propose"].waitForExistence(timeout: 10))
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: app.buttons["codex.propose"])
        waitForExpectations(timeout: 10)
        app.buttons["codex.propose"].click()
        XCTAssertTrue(app.staticTexts["codex.proposal-validated"].waitForExistence(timeout: 15), app.debugDescription)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Codex native experiment — deterministic fixture"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["codex.fresh"].click()
        XCTAssertTrue(app.staticTexts["Chat with Codex"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["codex.assistant-message"].exists)
    }
}
