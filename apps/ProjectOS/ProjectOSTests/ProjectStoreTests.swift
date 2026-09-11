import XCTest
import SQLite3
@testable import ProjectOS

final class ProjectStoreTests: XCTestCase {
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

    func testProjectsAndExactUnicodeSourcesSurviveReopen() throws {
        let project = try store.createProject(name: "Tuinkantoor", summary: "Plan lokaal")
        let original = "Budget: €12.000\nBesluit: glasvezel 🧵\n  Exacte witruimte."
        _ = try store.addSource(projectID: project.id, label: "Notities", text: original)
        store = try ProjectStore(url: directory.appending(path: "test.sqlite3"))

        XCTAssertEqual(try store.projects().map(\.id), [project.id])
        XCTAssertEqual(try store.sources(projectID: project.id).first?.text, original)
    }

    func testConversationListAndDraftsRemainIsolatedAcrossRelaunch() throws {
        let project = try store.createProject(name: "Office", summary: "")
        let first = try store.createConversation(projectID: project.id)
        let second = try store.createConversation(projectID: project.id)
        try store.saveMessage(MessageRecord(id: UUID(), projectID: project.id, conversationID: first.id, role: .user, text: "Foundation options", completion: .complete, createdAt: Date()))
        try store.saveMessage(MessageRecord(id: UUID(), projectID: project.id, conversationID: second.id, role: .user, text: "Heating options", completion: .complete, createdAt: Date()))
        try store.saveDraft(projectID: project.id, conversationID: first.id, text: "Ask about piles")
        try store.saveDraft(projectID: project.id, conversationID: second.id, text: "Ask about heat pump")
        store = try ProjectStore(url: directory.appending(path: "test.sqlite3"))

        XCTAssertEqual(try store.conversations(projectID: project.id).count, 2)
        XCTAssertEqual(try store.messages(projectID: project.id, conversationID: first.id).map(\.text), ["Foundation options"])
        XCTAssertEqual(try store.draft(projectID: project.id, conversationID: first.id), "Ask about piles")
        XCTAssertEqual(try store.draft(projectID: project.id, conversationID: second.id), "Ask about heat pump")
    }

    func testSchemaOneDatabaseMigratesToCurrentTables() throws {
        store = nil
        let url = directory.appending(path: "legacy.sqlite3")
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE projects (id TEXT PRIMARY KEY, data BLOB NOT NULL); PRAGMA user_version = 1;", nil, nil, nil), SQLITE_OK)
        sqlite3_close(database)

        store = try ProjectStore(url: url)
        let project = try store.createProject(name: "Migrated", summary: "")
        XCTAssertEqual(try store.createConversation(projectID: project.id).projectID, project.id)
        try store.saveRecommendation(RecommendationRecord(id: UUID(), projectID: project.id, text: "Continue", supportingRecords: [], uncertainty: "Needs evidence", originatingRevision: 0, createdAt: Date(), isDismissed: false))
        XCTAssertEqual(try store.recommendation(projectID: project.id)?.text, "Continue")
    }

    func testInjectedFailureRollsBackAcceptedProposal() throws {
        let project = try store.createProject(name: "Office", summary: "")
        let proposal = ProposalRecord(id: UUID(), projectID: project.id, originatingRevision: 0, kind: .decision, title: "Use fibre", content: "Use fibre for isolation.", rationale: nil, decisionSubject: "uplink", evidence: [], lifecycle: .pending, createdAt: Date())
        try store.saveProposals([proposal], expectedProjectRevision: 0)
        store.injectNextCommitFailure = true

        XCTAssertThrowsError(try store.acceptProposal(proposal.id))
        XCTAssertTrue(try store.artifacts(projectID: project.id).isEmpty)
        XCTAssertEqual(try store.proposals(projectID: project.id).first?.lifecycle, .pending)
        XCTAssertEqual(try store.projects().first?.revision, 0)
    }

    func testStaleAndDuplicateAcceptanceDoNotDoubleApply() throws {
        let project = try store.createProject(name: "Office", summary: "")
        let first = ProposalRecord(id: UUID(), projectID: project.id, originatingRevision: 0, kind: .task, title: "Check drainage", content: "Inspect drainage", rationale: nil, decisionSubject: nil, evidence: [], lifecycle: .pending, createdAt: Date())
        try store.saveProposals([first], expectedProjectRevision: 0)
        try store.acceptProposal(first.id)
        try store.acceptProposal(first.id)
        XCTAssertEqual(try store.artifacts(projectID: project.id).count, 1)
        XCTAssertEqual(try store.projects().first?.revision, 1)

        let stale = ProposalRecord(id: UUID(), projectID: project.id, originatingRevision: 0, kind: .topic, title: "Stale", content: "Old", rationale: nil, decisionSubject: nil, evidence: [], lifecycle: .pending, createdAt: Date())
        XCTAssertThrowsError(try store.saveProposals([stale], expectedProjectRevision: 0))
    }

    func testProposalsFromOneSnapshotCanEachBeAccepted() throws {
        let project = try store.createProject(name: "Bathroom", summary: "")
        let batch = ["Pump quote", "Order tiles", "Heating choice"].map { pendingProposal(project.id, title: $0, originatingRevision: 0) }
        try store.saveProposals(batch, expectedProjectRevision: 0)

        for proposal in batch { try store.acceptProposal(proposal.id) }

        XCTAssertEqual(try store.artifacts(projectID: project.id).count, 3)
        XCTAssertEqual(try store.projects().first?.revision, 3)
    }

    func testUnrelatedEditUndoOrOtherSnapshotStillMakesSiblingsStale() throws {
        let project = try store.createProject(name: "Bathroom", summary: "")
        let first = pendingProposal(project.id, title: "Pump quote", originatingRevision: 0)
        let sibling = pendingProposal(project.id, title: "Order tiles", originatingRevision: 0)
        let laterSibling = pendingProposal(project.id, title: "Heating choice", originatingRevision: 0)
        try store.saveProposals([first, sibling, laterSibling], expectedProjectRevision: 0)
        try store.acceptProposal(first.id)

        // A direct edit is not a sibling acceptance.
        let edit = ArtifactRecord(id: UUID(), projectID: project.id, kind: .topic, title: "Budget", content: "€12.000", state: .current, rationale: nil, decisionSubject: nil, evidence: [], version: 0, updatedAt: Date())
        try store.saveArtifact(edit, expectedProjectRevision: 1, summary: "Added topic")
        XCTAssertThrowsError(try store.acceptProposal(sibling.id)) { error in
            guard case ProjectStoreError.stale(0, 2) = error else { return XCTFail("Expected stale, got \(error)") }
        }

        // Undo of a sibling acceptance is also a change the batch was not reviewed against.
        let undoProject = try store.createProject(name: "Kitchen", summary: "")
        let undone = pendingProposal(undoProject.id, title: "Cabinets", originatingRevision: 0)
        let remaining = pendingProposal(undoProject.id, title: "Worktop", originatingRevision: 0)
        try store.saveProposals([undone, remaining], expectedProjectRevision: 0)
        try store.acceptProposal(undone.id)
        try store.undoLatest(projectID: undoProject.id)
        XCTAssertThrowsError(try store.acceptProposal(remaining.id))

        // Acceptance from a newer snapshot moves the project past this batch.
        let otherProject = try store.createProject(name: "Garden", summary: "")
        let old = pendingProposal(otherProject.id, title: "Fence", originatingRevision: 0)
        let oldSibling = pendingProposal(otherProject.id, title: "Gate", originatingRevision: 0)
        try store.saveProposals([old, oldSibling], expectedProjectRevision: 0)
        try store.acceptProposal(old.id)
        let newer = pendingProposal(otherProject.id, title: "Shed", originatingRevision: 1)
        try store.saveProposals([newer], expectedProjectRevision: 1)
        try store.acceptProposal(newer.id)
        XCTAssertThrowsError(try store.acceptProposal(oldSibling.id))

        XCTAssertEqual(try store.proposals(projectID: project.id).first { $0.id == sibling.id }?.lifecycle, .pending)
    }

    private func pendingProposal(_ projectID: UUID, title: String, originatingRevision: Int) -> ProposalRecord {
        ProposalRecord(id: UUID(), projectID: projectID, originatingRevision: originatingRevision, kind: .task, title: title, content: title, rationale: nil, decisionSubject: nil, evidence: [], lifecycle: .pending, createdAt: Date())
    }

    func testRejectingDependencyInvalidatesDependentsTransitively() throws {
        let project = try store.createProject(name: "Office", summary: "")
        let dependency = ProposalRecord(id: UUID(), projectID: project.id, originatingRevision: 0, kind: .research, title: "Check soil", content: "Inspect the soil.", rationale: nil, decisionSubject: nil, evidence: [], lifecycle: .pending, createdAt: Date())
        let dependent = ProposalRecord(id: UUID(), projectID: project.id, originatingRevision: 0, kind: .task, title: "Choose foundation", content: "Choose after inspection.", rationale: nil, decisionSubject: nil, evidence: [], dependencyIDs: [dependency.id], lifecycle: .pending, createdAt: Date())
        let transitive = ProposalRecord(id: UUID(), projectID: project.id, originatingRevision: 0, kind: .openQuestion, title: "Book builder?", content: "Wait for the foundation choice.", rationale: nil, decisionSubject: nil, evidence: [], dependencyIDs: [dependent.id], lifecycle: .deferred, createdAt: Date())
        try store.saveProposals([dependency, dependent, transitive], expectedProjectRevision: 0)

        try store.setProposal(dependency.id, lifecycle: .rejected)

        let byID = Dictionary(uniqueKeysWithValues: try store.proposals(projectID: project.id).map { ($0.id, $0) })
        XCTAssertEqual(byID[dependency.id]?.lifecycle, .rejected)
        XCTAssertEqual(byID[dependent.id]?.lifecycle, .invalidated)
        XCTAssertEqual(byID[transitive.id]?.lifecycle, .invalidated)
        XCTAssertEqual(try store.projects().first?.revision, 0)
    }

    func testDecisionReplacementMustBeExplicitAndUndoRestoresReview() throws {
        let project = try store.createProject(name: "Office", summary: "")
        let prior = ArtifactRecord(id: UUID(), projectID: project.id, kind: .decision, title: "Use fibre", content: "Use fibre.", state: .current, rationale: "Reliable", decisionSubject: " Uplínk ", evidence: [], version: 0, updatedAt: Date())
        try store.saveArtifact(prior, expectedProjectRevision: 0, summary: "Added decision")
        let proposal = ProposalRecord(id: UUID(), projectID: project.id, originatingRevision: 1, kind: .decision, title: "Use wireless", content: "Use wireless.", rationale: "Cheaper", decisionSubject: "uplink", evidence: [], lifecycle: .pending, createdAt: Date())
        try store.saveProposals([proposal], expectedProjectRevision: 1)

        XCTAssertThrowsError(try store.acceptProposal(proposal.id))
        try store.markProposalAsSuperseding(proposal.id, priorDecisionID: prior.id)
        try store.acceptProposal(proposal.id, editedTitle: "Use managed wireless")

        let accepted = try store.artifacts(projectID: project.id)
        XCTAssertEqual(accepted.filter { $0.kind == .decision && $0.state == .current }.count, 1)
        XCTAssertEqual(accepted.first { $0.state == .superseded }?.id, prior.id)
        XCTAssertEqual(try store.proposals(projectID: project.id).first?.acceptedTitle, "Use managed wireless")

        try store.undoLatest(projectID: project.id)
        XCTAssertEqual(try store.artifacts(projectID: project.id).first { $0.id == prior.id }?.state, .current)
        XCTAssertEqual(try store.proposals(projectID: project.id).first?.lifecycle, .pending)
    }

    func testAcceptedProposalPreservesStateAndResearchQualification() throws {
        let project = try store.createProject(name: "Office", summary: "")
        let task = ArtifactRecord(id: UUID(), projectID: project.id, kind: .task, title: "Inspect", content: "Inspect soil.", state: .open, rationale: nil, decisionSubject: nil, evidence: [], version: 0, updatedAt: Date())
        try store.saveArtifact(task, expectedProjectRevision: 0, summary: "Added task")
        let update = ProposalRecord(id: UUID(), projectID: project.id, originatingRevision: 1, operation: .update, targetID: task.id, expectedTargetRevision: 1, kind: .task, title: task.title, content: "Inspection completed.", rationale: nil, decisionSubject: nil, proposedState: .done, evidence: [], lifecycle: .pending, createdAt: Date())
        try store.saveProposals([update], expectedProjectRevision: 1)
        try store.acceptProposal(update.id)
        XCTAssertEqual(try store.artifacts(projectID: project.id).first { $0.id == task.id }?.state, .done)

        let research = ProposalRecord(id: UUID(), projectID: project.id, originatingRevision: 2, kind: .research, title: "Soil report", content: "Clay layer present.", rationale: nil, decisionSubject: nil, certainty: "Moderate", limitations: "One sample", evidence: [], lifecycle: .pending, createdAt: Date())
        try store.saveProposals([research], expectedProjectRevision: 2)
        try store.acceptProposal(research.id)
        let acceptedResearch = try store.artifacts(projectID: project.id).first { $0.kind == .research }
        XCTAssertEqual(acceptedResearch?.certainty, "Moderate")
        XCTAssertEqual(acceptedResearch?.limitations, "One sample")
    }

    func testUndoAppendsCompensatingHistory() throws {
        let project = try store.createProject(name: "Office", summary: "")
        let artifact = ArtifactRecord(id: UUID(), projectID: project.id, kind: .openQuestion, title: "Drainage", content: "How?", state: .open, rationale: nil, decisionSubject: nil, evidence: [], version: 0, updatedAt: Date())
        try store.saveArtifact(artifact, expectedProjectRevision: 0, summary: "Added question")
        try store.undoLatest(projectID: project.id)
        XCTAssertTrue(try store.artifacts(projectID: project.id).isEmpty)
        XCTAssertEqual(try store.changes(projectID: project.id).count, 2)
        XCTAssertEqual(try store.projects().first?.revision, 2)
    }

    func testVerifiedArchiveRestoresSeparateEquivalentCopyAndUndoHistory() async throws {
        let project = try store.createProject(name: "Tuin", summary: "Kantoor")
        let source = try store.addSource(projectID: project.id, label: "Notities", text: "Budget €12.000 — drainage open")
        let message = MessageRecord(id: UUID(), projectID: project.id, conversationID: UUID(), role: .user, text: "Gebruik glasvezel", completion: .complete, createdAt: Date())
        try store.saveMessage(message)
        let artifact = ArtifactRecord(id: UUID(), projectID: project.id, kind: .openQuestion, title: "Drainage", content: "Hoe voeren we water af?", state: .open, rationale: "Nog niet besloten", decisionSubject: nil, evidence: [EvidenceRecord(id: UUID(), sourceType: "source", sourceID: source.id, version: 1, quote: "drainage open", aiAuthored: false)], version: 0, updatedAt: Date())
        try store.saveArtifact(artifact, expectedProjectRevision: 0, summary: "Added drainage question")
        try store.saveDraft(projectID: project.id, conversationID: message.conversationID, text: "Volgende gesprek")
        try store.saveOutcome(ReturnRecord(id: UUID(), projectID: project.id, durationMinutes: 4, understanding: 4, trust: 4, usefulness: 5, resumedWithinFiveMinutes: true, actionOutcome: "Different action", reviewMinutes: 2, projectOutcome: "Unresolved", notes: "Useful", createdAt: Date()))
        try store.saveRecommendation(RecommendationRecord(id: UUID(), projectID: project.id, text: "Resolve drainage", supportingRecords: [RecommendationSupport(id: artifact.id, version: 1)], uncertainty: nil, originatingRevision: 1, createdAt: Date(), isDismissed: false))
        try store.saveJob(InferenceJobRecord(id: UUID(), contextID: UUID(), projectID: project.id, sourceRevision: 1, provider: "Ollama", model: "local", purpose: "chat", sourceIDs: [source.id], artifactIDs: [artifact.id], messageIDs: [message.id], createdAt: Date(), status: .completed))

        let archive = directory.appending(path: "Tuin.projectos", directoryHint: .isDirectory)
        let service = ProjectArchiveService()
        _ = try await service.exportProject(id: project.id, from: store, to: archive)
        let receipt = try await service.restoreProject(from: archive, into: store)

        XCTAssertNotEqual(receipt.restoredProjectID, project.id)
        XCTAssertEqual(try store.sources(projectID: receipt.restoredProjectID).first?.text, "Budget €12.000 — drainage open")
        XCTAssertEqual(try store.messages(projectID: receipt.restoredProjectID).first?.text, "Gebruik glasvezel")
        let restoredConversation = try XCTUnwrap(store.conversations(projectID: receipt.restoredProjectID).first)
        XCTAssertEqual(try store.draft(projectID: receipt.restoredProjectID, conversationID: restoredConversation.id), "Volgende gesprek")
        XCTAssertEqual(try store.outcomes(projectID: receipt.restoredProjectID).count, 1)
        XCTAssertEqual(try store.jobs(projectID: receipt.restoredProjectID).count, 1)
        XCTAssertEqual(try store.recommendation(projectID: receipt.restoredProjectID)?.text, "Resolve drainage")
        try store.undoLatest(projectID: receipt.restoredProjectID)
        XCTAssertTrue(try store.artifacts(projectID: receipt.restoredProjectID).isEmpty)
    }

    func testCorruptArchiveIsRejectedWithoutCreatingProject() async throws {
        let project = try store.createProject(name: "Original", summary: "")
        let archive = directory.appending(path: "Original.projectos", directoryHint: .isDirectory)
        let service = ProjectArchiveService()
        _ = try await service.exportProject(id: project.id, from: store, to: archive)
        try Data("corrupt".utf8).write(to: archive.appending(path: "project.json"))
        let count = try store.projects().count
        do {
            _ = try await service.restoreProject(from: archive, into: store)
            XCTFail("Expected corrupt archive rejection")
        } catch {}
        XCTAssertEqual(try store.projects().count, count)
    }

    func testDeletionFenceRejectsLateWrites() async throws {
        let project = try store.createProject(name: "Delete Me", summary: "")
        let fence = try await store.beginDeletion(of: project.id, expectedName: project.name)
        let late = MessageRecord(id: UUID(), projectID: project.id, conversationID: UUID(), role: .assistant, text: "late", completion: .complete, createdAt: Date())
        XCTAssertThrowsError(try store.saveMessage(late))
        try await store.deleteProjectAtomically(using: fence)
        XCTAssertFalse(try store.projects().contains { $0.id == project.id })
        XCTAssertThrowsError(try store.saveMessage(late))
    }
}
