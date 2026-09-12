import XCTest
@testable import ProjectOS

/// A page saved as a source has to stay traceable to the page it came from,
/// through relaunches and through an export and restore, or a citation loses
/// its provenance.
final class WebSourceStoreTests: XCTestCase {
    private var directory: URL!
    private var store: ProjectStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "ProjectOSTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = try ProjectStore(url: directory.appending(path: "test.sqlite3"))
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: directory)
    }

    func testSavedPageKeepsItsAddressAndRetrievalTimeAcrossRelaunch() throws {
        let project = try store.createProject(name: "Tuinkantoor", summary: "")
        let page = WebPageSnapshot(
            url: URL(string: "https://example.com/drainage")!,
            title: "Drainage rules",
            text: "Rainwater must stay on the plot.",
            fetchedAt: Date()
        )

        _ = try store.addSource(projectID: project.id, label: page.title, text: page.text, origin: page.origin)
        store = try ProjectStore(url: directory.appending(path: "test.sqlite3"))

        let restored = try XCTUnwrap(store.sources(projectID: project.id).first)
        XCTAssertEqual(restored.text, page.text, "The retained copy is what records quote.")
        XCTAssertEqual(restored.origin?.url, page.url)
        XCTAssertEqual(restored.origin?.title, "Drainage rules")
        XCTAssertTrue(restored.origin?.matches(page) == true)
    }

    func testPastedSourceHasNoWebOrigin() throws {
        let project = try store.createProject(name: "Tuinkantoor", summary: "")

        _ = try store.addSource(projectID: project.id, label: "Notes", text: "Budget €12.000")

        XCTAssertNil(try store.sources(projectID: project.id).first?.origin)
    }

    func testWebResearchIsOnForResearchConversationsAndOffForOthers() throws {
        let project = try store.createProject(name: "Tuinkantoor", summary: "")
        let research = ArtifactRecord(id: UUID(), projectID: project.id, kind: .research, title: "Heat pump options", content: "Which pump suits the house?", state: .open, rationale: nil, decisionSubject: nil, evidence: [], version: 0, updatedAt: Date())
        try store.saveArtifact(research, expectedProjectRevision: 0, summary: "Added research")

        let ordinary = try store.createConversation(projectID: project.id)
        let researchConversation = try store.createConversation(projectID: project.id, researchID: research.id)

        XCTAssertFalse(ordinary.usesWebResearch)
        XCTAssertTrue(researchConversation.usesWebResearch)

        let switchedOff = try store.setWebResearch(false, conversationID: researchConversation.id, projectID: project.id)
        let switchedOn = try store.setWebResearch(true, conversationID: ordinary.id, projectID: project.id)

        XCTAssertFalse(switchedOff.usesWebResearch)
        XCTAssertTrue(switchedOn.usesWebResearch)

        store = try ProjectStore(url: directory.appending(path: "test.sqlite3"))
        let reloaded = try store.conversations(projectID: project.id)
        XCTAssertEqual(reloaded.first { $0.id == researchConversation.id }?.usesWebResearch, false)
        XCTAssertEqual(reloaded.first { $0.id == ordinary.id }?.usesWebResearch, true)
    }

    func testExportAndRestoreKeepTheWayBackToTheOriginalPage() async throws {
        let project = try store.createProject(name: "Tuinkantoor", summary: "")
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let origin = SourceOrigin(url: URL(string: "https://example.com/drainage")!, title: "Drainage rules", fetchedAt: fetchedAt)
        _ = try store.addSource(projectID: project.id, label: origin.title, text: "Rainwater must stay on the plot.", origin: origin)

        let archive = directory.appending(path: "Tuin.projectos", directoryHint: .isDirectory)
        let service = ProjectArchiveService()
        _ = try await service.exportProject(id: project.id, from: store, to: archive)
        let receipt = try await service.restoreProject(from: archive, into: store)

        let restored = try XCTUnwrap(store.sources(projectID: receipt.restoredProjectID).first)
        XCTAssertEqual(restored.origin?.url, origin.url)
        XCTAssertEqual(restored.origin?.title, "Drainage rules")
        XCTAssertEqual(restored.origin?.fetchedAt.timeIntervalSince1970 ?? 0, fetchedAt.timeIntervalSince1970, accuracy: 1)
    }

    func testResearchTrailIsKeptWithTheReply() throws {
        let project = try store.createProject(name: "Tuinkantoor", summary: "")
        let conversation = try store.createConversation(projectID: project.id)
        let page = WebPageSnapshot(url: URL(string: "https://example.com/a")!, title: "A", text: "Body", fetchedAt: Date())
        let steps = [
            WebResearchStep(action: .search, subject: "drainage", status: .done, results: []),
            WebResearchStep(action: .read, subject: page.url.absoluteString, status: .done, page: page)
        ]
        let reply = MessageRecord(id: UUID(), projectID: project.id, conversationID: conversation.id, role: .assistant, text: "Answer", completion: .complete, createdAt: Date(), research: steps)

        try store.saveMessage(reply)
        store = try ProjectStore(url: directory.appending(path: "test.sqlite3"))

        let restored = try XCTUnwrap(store.messages(projectID: project.id, conversationID: conversation.id).first)
        XCTAssertEqual(restored.research?.count, 2)
        XCTAssertEqual(restored.research?.last?.page?.url, page.url)
    }

    func testAnInterruptedStepIsRecordedAsFailedRatherThanStillRunning() {
        let running = WebResearchStep(action: .read, subject: "https://example.com/a", status: .running)

        let ended = running.interrupted()

        XCTAssertEqual(ended.status, .failed)
        XCTAssertNotNil(ended.failure)
        XCTAssertEqual(WebResearchStep(action: .search, subject: "q", status: .done).interrupted().status, .done)
    }
}
