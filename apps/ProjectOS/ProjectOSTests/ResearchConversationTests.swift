import XCTest
@testable import ProjectOS

/// Research has its own lifecycle and is worked on in conversations linked to
/// it. These pin the stored shape of both.
final class ResearchConversationTests: XCTestCase {
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

    func testResearchSavedAsCurrentReadsAsOpen() throws {
        let legacyResearch = record(kind: .research, state: .current)
        let topic = record(kind: .topic, state: .current)

        let decoded = try JSONDecoder().decode([ArtifactRecord].self, from: JSONEncoder().encode([legacyResearch, topic]))

        XCTAssertEqual(decoded[0].state, .open, "Research from before its own lifecycle starts Open.")
        XCTAssertEqual(decoded[1].state, .current, "Other kinds keep their stored status.")
    }

    func testResearchStartsOpenAndMovesThroughItsOwnStatuses() {
        XCTAssertEqual(ArtifactKind.research.initialState, .open)
        XCTAssertEqual(ArtifactKind.research.allowedStates, [.open, .inProgress, .done, .removed])
        XCTAssertFalse(ArtifactKind.research.allowedStates.contains(.current))
    }

    func testSeveralConversationsStayLinkedToOneResearchItemAcrossRelaunch() throws {
        let project = try store.createProject(name: "Garden office", summary: "")
        let research = record(kind: .research, state: .open, projectID: project.id)
        try store.saveArtifact(research, expectedProjectRevision: project.revision, summary: "Added research")

        let first = try store.createConversation(projectID: project.id, researchID: research.id)
        let second = try store.createConversation(projectID: project.id, researchID: research.id)
        let unrelated = try store.createConversation(projectID: project.id)
        store = try ProjectStore(url: directory.appending(path: "test.sqlite3"))

        let byID = Dictionary(uniqueKeysWithValues: try store.conversations(projectID: project.id).map { ($0.id, $0) })
        XCTAssertEqual(byID[first.id]?.researchID, research.id)
        XCTAssertEqual(byID[second.id]?.researchID, research.id)
        XCTAssertNil(byID[unrelated.id]?.researchID)
    }

    func testConversationCannotLinkARecordThatIsNotThisProjectsResearch() throws {
        let project = try store.createProject(name: "Garden office", summary: "")
        let other = try store.createProject(name: "Used car", summary: "")
        let topic = record(kind: .topic, state: .current, projectID: project.id)
        let foreignResearch = record(kind: .research, state: .open, projectID: other.id)
        try store.saveArtifact(topic, expectedProjectRevision: project.revision, summary: "Added topic")
        try store.saveArtifact(foreignResearch, expectedProjectRevision: other.revision, summary: "Added research")

        XCTAssertThrowsError(try store.createConversation(projectID: project.id, researchID: topic.id))
        XCTAssertThrowsError(try store.createConversation(projectID: project.id, researchID: foreignResearch.id))
        XCTAssertThrowsError(try store.createConversation(projectID: project.id, researchID: UUID()))
    }

    func testFocusPromptNamesTheResearchByIDOnly() {
        let id = UUID().uuidString
        let prompt = PromptFactory.researchFocusPrompt(artifactID: id)

        XCTAssertTrue(prompt.contains("id=\"\(id)\""))
        XCTAssertTrue(prompt.contains("cannot browse"))
    }

    private func record(kind: ArtifactKind, state: ArtifactState, projectID: UUID = UUID()) -> ArtifactRecord {
        ArtifactRecord(id: UUID(), projectID: projectID, kind: kind, title: "Soil bearing capacity", content: "Can the clay layer carry a slab?", state: state, rationale: nil, decisionSubject: nil, evidence: [], version: 0, updatedAt: Date())
    }
}
