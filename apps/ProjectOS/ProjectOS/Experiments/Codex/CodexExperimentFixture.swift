import Foundation

/// Explicit opt-in fixture for native UI verification. Never used by normal pairing.
@MainActor
final class CodexExperimentFixture: CodexExperimentTransport {
    private var queue: [JSONValue] = []
    private var sequence = 0
    private var sessionID = "fixture-session"
    private var cancelled = false

    func rpc(_ method: String, _ params: [String: JSONValue]) async throws -> JSONValue {
        switch method {
        case "initialize": return .object(["agentCapabilities": .object(["loadSession": .bool(true)])])
        case "session/new", "session/load":
            sessionID = params[acp: "sessionId"].acpString ?? "fixture-\(UUID())"
            return .object(["sessionId": .string(sessionID), "models": .object(["currentModelId": .string("fixture-model"), "availableModels": .array([.object(["modelId": .string("fixture-model"), "name": .string("Fixture model (not live)")])])])])
        case "session/cancel": cancelled = true; return .object([:])
        case "session/prompt":
            cancelled = false
            let proposal = params[acp: "prompt"].acpArray.first?[acp: "text"].acpString?.contains("production schema") == true
            append(["sessionUpdate": .string("tool_call"), "toolCallId": .string("fixture-search"), "kind": .string("search"), "title": .string("Fixture: Codex web search"), "status": .string("completed")])
            let text = proposal ? Self.proposalJSON : "Synthetic fixture response: insulation and heat loss determine heat-pump suitability. This is deterministic UI evidence, not live research."
            for part in text.split(separator: " ", omittingEmptySubsequences: false) {
                if cancelled { break }
                append(["sessionUpdate": .string("agent_message_chunk"), "content": .object(["type": .string("text"), "text": .string(String(part) + " ")])])
                try await Task.sleep(for: .milliseconds(20))
            }
            return .object(["stopReason": .string(cancelled ? "cancelled" : "end_turn")])
        default: return .object([:])
        }
    }

    func events(after cursor: Int) async throws -> JSONValue {
        .object(["events": .array(queue.filter { ($0[acp: "seq"].acpInt ?? 0) > cursor }), "cursor": .number(Double(sequence))])
    }
    func permission(id: String, optionID: String) async throws {}

    private func append(_ update: [String: JSONValue]) {
        sequence += 1
        queue.append(.object(["seq": .number(Double(sequence)), "kind": .string("notification"), "method": .string("session/update"), "params": .object(["sessionId": .string(sessionID), "update": .object(update)])]))
    }

    static var proposalJSON: String {
        """
        {"schemaVersion":1,"proposals":[{"temporaryID":"F48D35E1-97D4-4F14-8CCC-000000000001","operation":"create","kind":"open_question","targetID":null,"expectedTargetRevision":null,"title":"Would a heat pump provide year-round comfort?","content":"Determine whether a heat pump meets the garden office comfort needs.","rationale":"The synthetic user preference is conditional.","decisionSubject":null,"state":"open","certainty":null,"limitations":null,"evidence":[{"sourceType":"source","referenceID":"\(CodexExperimentModel.evidenceID.uuidString)","version":1,"quote":"I prefer a heat pump if the evidence supports year-round comfort."}],"relationships":[],"dependencyIDs":[]}]}
        """
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    subscript(acp key: String) -> JSONValue { self[key] ?? .null }
}
