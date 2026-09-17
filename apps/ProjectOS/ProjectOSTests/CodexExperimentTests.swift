import XCTest
@testable import ProjectOS

@MainActor
final class CodexExperimentTests: XCTestCase {
    private func stateURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "CodexExperimentTests-\(UUID())/state.json")
    }

    func testPairingRejectsRemoteAddressesAndInvalidTokens() throws {
        XCTAssertThrowsError(try CodexLoopbackTransport(pairing: "https://example.com:token"))
        XCTAssertThrowsError(try CodexLoopbackTransport(pairing: "0:" + String(repeating: "a", count: 64)))
        XCTAssertThrowsError(try CodexLoopbackTransport(pairing: "1234:short"))
        XCTAssertEqual(try CodexLoopbackTransport(pairing: "1234:" + String(repeating: "a", count: 64)).port, 1234)
    }

    func testLiveCapturedProposalPassesAndFabricatedEvidenceFails() throws {
        // Exact answer from the authenticated live run on 2026-09-16; see spike evidence/live-proposal.json.
        let captured = #"{"schemaVersion":1,"proposals":[{"temporaryID":"8f63cde9-7bd2-45ea-90a6-d1c0e59b7423","operation":"create","kind":"open_question","targetID":null,"expectedTargetRevision":null,"title":"Which heating option should the garden office use?","content":"Would a heat pump provide quiet, year-round comfort for the well-insulated garden office in the Netherlands, given the unresolved budget and installation feasibility?","rationale":null,"decisionSubject":null,"state":"open","certainty":null,"limitations":null,"evidence":[{"sourceType":"source","referenceID":"A48D35E1-97D4-4F14-8CCC-000000000002","version":1,"quote":"Synthetic garden-office project. I want a quiet, well-insulated garden office in the Netherlands. I prefer a heat pump if the evidence supports year-round comfort. Budget and installation feasibility remain undecided."}],"relationships":[],"dependencyIDs":[]}]}"#
        let proposals = try CodexExperimentModel.validateProposal(captured)
        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals[0].kind.rawValue, "open_question")
        XCTAssertEqual(proposals[0].evidence.first?.quote, CodexExperimentModel.syntheticContext)
        XCTAssertThrowsError(try CodexExperimentModel.validateProposal(captured.replacingOccurrences(of: "Budget and installation feasibility remain undecided.", with: "Budget is approved.")))
        XCTAssertThrowsError(try CodexExperimentModel.validateProposal("Here is repaired JSON: " + captured))
        XCTAssertThrowsError(try CodexExperimentModel.validateProposal("{\"schemaVersion\":1,\"proposals\":[]}"))
    }

    func testContextDeselectionPreservesHistoryAndFreshClearsIt() async throws {
        let url = stateURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = CodexExperimentModel(stateURL: url)
        let client = CodexExperimentFixture()
        await model.connect(using: client, resume: false)
        model.draft = "Discuss the synthetic project"
        await model.send()
        XCTAssertTrue(model.state.contextWasSent)
        XCTAssertEqual(model.state.messages.count, 2)
        model.includeContext = false
        XCTAssertTrue(model.retainedContextDescription.contains("including the synthetic project context"))
        let restored = CodexExperimentModel(stateURL: url)
        XCTAssertEqual(restored.state.messages, model.state.messages)
        XCTAssertEqual(restored.state.sessionID, model.state.sessionID)
        await model.fresh()
        XCTAssertFalse(model.state.contextWasSent)
        XCTAssertTrue(model.state.messages.isEmpty)
        let archives = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent().appending(path: "archives"), includingPropertiesForKeys: nil)
        XCTAssertEqual(archives.count, 1)
        let archived = try JSONDecoder().decode(CodexExperimentState.self, from: Data(contentsOf: archives[0]))
        XCTAssertEqual(archived.messages, restored.state.messages)
        model.disconnect()
    }

    func testDuplicateAndReplayEventsDoNotDuplicateTranscriptAndStopRejectsLateText() async throws {
        let url = stateURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = CodexExperimentModel(stateURL: url)
        let client = SuspendedCodexTransport()
        await model.connect(using: client, resume: false)
        model.draft = "Synthetic test"
        let task = Task { await model.send() }
        for _ in 0..<100 where !client.promptStarted { await Task.yield() }
        XCTAssertTrue(client.promptStarted)
        let first = client.event(sequence: 1, text: "retained")
        model.consume(first); model.consume(first)
        model.consume(client.event(sequence: 2, text: "replayed", replay: true))
        XCTAssertEqual(model.state.messages.last?.text, "retained")
        await model.stop()
        model.consume(client.event(sequence: 3, text: "late"))
        client.finish()
        await task.value
        XCTAssertEqual(model.state.messages.last?.text, "retained")
        XCTAssertEqual(model.state.messages.last?.status, "interrupted")
        XCTAssertEqual(client.cancelCount, 1)
        XCTAssertFalse(model.busy)
        model.disconnect()
    }

    func testProposalRemainsPendingAndNeverNeedsProductionStore() async throws {
        let url = stateURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = CodexExperimentModel(stateURL: url)
        await model.connect(using: CodexExperimentFixture(), resume: false)
        await model.send(proposal: true)
        XCTAssertNil(model.error)
        XCTAssertEqual(model.pendingProposals.count, 1)
        XCTAssertTrue(model.status.contains("no project changes applied"))
        model.disconnect()
        XCTAssertEqual(CodexExperimentModel(stateURL: url).pendingProposals.count, 1)
    }

    func testCorruptHistoryIsReported() throws {
        let url = stateURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("invalid".utf8).write(to: url)
        let model = CodexExperimentModel(stateURL: url)
        XCTAssertTrue(model.error?.contains("history could not be loaded") == true)
        model.disconnect()
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "invalid")
    }

    func testStoredResearchPreferenceCannotEnableSearXNGForOpenRouter() {
        let environment = AppEnvironment()
        let conversation = ConversationRecord(id: UUID(), projectID: UUID(), title: "Research", createdAt: Date(), updatedAt: Date(), webResearch: true)
        environment.conversations = [conversation]
        environment.selectedConversationID = conversation.id
        environment.provider = .ollama
        XCTAssertTrue(environment.usesWebResearch)
        environment.provider = .openRouter
        XCTAssertFalse(environment.usesWebResearch)
        XCTAssertTrue(environment.webResearchDisclosure.contains("only with local Ollama"))
        environment.provider = .ollama
        XCTAssertTrue(environment.usesWebResearch, "Preserve the conversation preference for a return to a local model")
    }
}

@MainActor
private final class SuspendedCodexTransport: CodexExperimentTransport {
    var promptStarted = false
    var cancelCount = 0
    private var pending: CheckedContinuation<JSONValue, Never>?

    func rpc(_ method: String, _ params: [String: JSONValue]) async throws -> JSONValue {
        if method == "session/prompt" {
            promptStarted = true
            return await withCheckedContinuation { pending = $0 }
        }
        if method == "session/cancel" { cancelCount += 1 }
        return .object(["sessionId": .string("s"), "models": .object(["currentModelId": .string("fixture"), "availableModels": .array([.object(["modelId": .string("fixture")])])])])
    }
    func events(after cursor: Int) async throws -> JSONValue { .object(["events": .array([]), "cursor": .number(Double(cursor))]) }
    func permission(id: String, optionID: String) async throws {}
    func finish() { pending?.resume(returning: .object(["stopReason": .string("cancelled")])); pending = nil }
    func event(sequence: Int, text: String, replay: Bool = false) -> JSONValue {
        .object(["seq": .number(Double(sequence)), "replay": .bool(replay), "kind": .string("notification"), "params": .object(["sessionId": .string("s"), "update": .object(["sessionUpdate": .string("agent_message_chunk"), "content": .object(["type": .string("text"), "text": .string(text)])])])])
    }
}
