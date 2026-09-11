import XCTest
@testable import ProjectOS

/// The toolbar's account of a provider request must stay truthful: phases only
/// move forward, and the first ending is the one that sticks.
final class GenerationActivityTests: XCTestCase {
    func testPhasesOnlyMoveForward() {
        var activity = makeActivity(purpose: .proposals)

        XCTAssertTrue(activity.advance(to: .receiving))
        XCTAssertFalse(activity.advance(to: .waiting), "A late 'waiting' report must not rewind the timeline.")
        XCTAssertFalse(activity.advance(to: .receiving), "Repeated reports of the same phase change nothing.")
        XCTAssertEqual(activity.phase, .receiving)
    }

    func testTimelineMarksDoneCurrentAndPendingSteps() {
        var activity = makeActivity(purpose: .proposals)
        activity.advance(to: .receiving)

        XCTAssertEqual(activity.steps.map(activity.state(of:)), [.done, .done, .current, .pending, .pending])
        XCTAssertEqual(activity.headline, "Drafting project updates")
    }

    func testFailureMarksTheStepItHappenedInAndSkipsTheRest() {
        var activity = makeActivity(purpose: .proposals)
        activity.advance(to: .checking)
        activity.finish(.failed("Evidence did not match."))

        XCTAssertEqual(activity.steps.map(activity.state(of:)), [.done, .done, .done, .failed, .skipped])
        XCTAssertFalse(activity.isRunning)
        XCTAssertEqual(activity.headline, "Project updates failed")
    }

    func testFirstEndingSticksAndEndedActivityCannotAdvance() {
        var activity = makeActivity(purpose: .chat)
        activity.advance(to: .receiving)
        XCTAssertTrue(activity.finish(.stopped))

        XCTAssertFalse(activity.finish(.failed("Cancelled")), "The provider's cancellation error must not turn a stop into a failure.")
        XCTAssertFalse(activity.advance(to: .checking))
        XCTAssertEqual(activity.outcome, .stopped)
        XCTAssertEqual(activity.state(of: .receiving), .stopped)
    }

    func testCompletedActivityShowsEveryStepDone() {
        var activity = makeActivity(purpose: .chat)
        activity.advance(to: .receiving)
        activity.finish(.completed("Reply complete"))

        XCTAssertEqual(activity.steps.map(activity.state(of:)), [.done, .done, .done])
        XCTAssertEqual(activity.headline, "Reply complete")
    }

    func testChatHasNoCheckingOrSavingStep() {
        XCTAssertEqual(AIJobPurpose.chat.steps, [.preparing, .waiting, .receiving])
    }

    func testContextSummaryNamesOnlyWhatWasSent() {
        XCTAssertEqual(
            GenerationActivity.contextSummary(includesDescription: true, sources: 1, records: 0, messages: 12),
            "Project description · 1 source · 12 messages"
        )
        XCTAssertEqual(
            GenerationActivity.contextSummary(includesDescription: false, sources: 0, records: 3, messages: 0),
            "3 records"
        )
        XCTAssertEqual(
            GenerationActivity.contextSummary(includesDescription: false, sources: 0, records: 0, messages: 0),
            "No project context"
        )
    }

    func testWaitingDetailExplainsWhereTheTimeGoes() {
        let local = AIJobPhase.waiting.detail(for: .chat, runsLocally: true, route: nil)
        let external = AIJobPhase.waiting.detail(for: .chat, runsLocally: false, route: "anthropic")

        XCTAssertTrue(local.contains("loads the model"))
        XCTAssertTrue(external.contains("anthropic"))
    }

    private func makeActivity(purpose: AIJobPurpose) -> GenerationActivity {
        GenerationActivity(
            id: UUID(),
            projectID: UUID(),
            projectName: "Garden office",
            purpose: purpose,
            provider: .ollama,
            model: "gemma3:12b",
            route: nil,
            contextSummary: "2 sources"
        )
    }
}
