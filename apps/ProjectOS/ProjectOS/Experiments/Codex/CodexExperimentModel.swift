import Foundation
import SwiftUI
import ProjectOSCore

struct CodexExperimentMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: String
    var text: String
    var status = "complete"
    var addedContext = false
}

struct CodexExperimentState: Codable {
    var sessionID: String?
    var modelID = ""
    var messages: [CodexExperimentMessage] = []
    var contextWasSent = false
    var pendingProposalJSON: String?
}

struct CodexExperimentActivity: Identifiable {
    var id: String
    var title: String
    var kind: String
    var status: String
}

struct CodexExperimentPermission: Identifiable {
    var id: String
    var title: String
    var options: [Option]
    struct Option: Identifiable { var id: String; var name: String }
}

@MainActor
final class CodexExperimentModel: ObservableObject {
    static let projectID = UUID(uuidString: "A48D35E1-97D4-4F14-8CCC-000000000001")!
    static let evidenceID = UUID(uuidString: "A48D35E1-97D4-4F14-8CCC-000000000002")!
    static let syntheticContext = "Synthetic garden-office project. I want a quiet, well-insulated garden office in the Netherlands. I prefer a heat pump if the evidence supports year-round comfort. Budget and installation feasibility remain undecided."

    @Published private(set) var state: CodexExperimentState
    @Published var pairing = ""
    @Published var draft = "Research heat pumps for this garden office using Codex web search. Cite your sources and explain the uncertainties."
    @Published var includeContext = true
    @Published var selectedModel = ""
    @Published private(set) var models: [(id: String, name: String)] = []
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    @Published private(set) var activities: [CodexExperimentActivity] = []
    @Published private(set) var permissions: [CodexExperimentPermission] = []
    @Published private(set) var pendingProposals: [ProjectOSCore.Proposal] = []
    @Published private(set) var status = "Start the helper, then paste its pairing code."
    @Published private(set) var error: String?

    private let stateURL: URL
    private var transport: (any CodexExperimentTransport)?
    private var polling: Task<Void, Never>?
    private var cursor = 0
    private var generation = UUID()
    private var assistantID: UUID?
    private var stopped = false
    private var phase = ""
    private var pollInFlight = false
    private var persistenceBlocked = false

    init(stateURL: URL? = nil) {
        self.stateURL = stateURL ?? Self.defaultStateURL
        state = CodexExperimentState()
        if FileManager.default.fileExists(atPath: self.stateURL.path) {
            do {
                var loaded = try JSONDecoder().decode(CodexExperimentState.self, from: Data(contentsOf: self.stateURL))
                for index in loaded.messages.indices where loaded.messages[index].status == "streaming" { loaded.messages[index].status = "interrupted" }
                state = loaded
                if let json = loaded.pendingProposalJSON { pendingProposals = try Self.validateProposal(json) }
            } catch {
                persistenceBlocked = true
                self.error = "Saved history could not be loaded; original file preserved and saving disabled: \(error.localizedDescription)"
            }
        }
        selectedModel = state.modelID
    }

    static var defaultStateURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "ProjectOS/CodexExperiment/state.json")
    }

    var retainedContextDescription: String {
        guard state.sessionID != nil else { return "No agent session yet." }
        if state.messages.isEmpty { return "Fresh agent session. No earlier conversation or project context has been sent." }
        return "Codex retains this session's earlier turns\(state.contextWasSent ? ", including the synthetic project context" : ""). After an interrupted connection, Codex may remember output missing from this local transcript. Deselecting context only changes the next turn. Start fresh to omit remembered history."
    }

    var canStartFresh: Bool { transport != nil && !busy }

    func connect(resume: Bool) async {
        do {
            let client = try CodexLoopbackTransport(pairing: pairing)
            pairing = ""
            await connect(using: client, resume: resume)
        } catch { self.error = error.localizedDescription }
    }

    func connect(using client: any CodexExperimentTransport, resume: Bool) async {
        guard !busy else { return }
        guard !persistenceBlocked else { error = "Preserve or move the unreadable experiment state file, then restart the app."; return }
        let connection = UUID(); generation = connection
        busy = true; error = nil; connected = false
        defer { if generation == connection { busy = false } }
        polling?.cancel(); cursor = 0; transport = client
        do {
            let initialized = try await client.rpc("initialize", [:])
            guard generation == connection else { return }
            if resume && initialized[acp: "agentCapabilities"][acp: "loadSession"] != .bool(true) {
                throw CodexExperimentError.message("This agent cannot resume sessions. Start a fresh session explicitly.")
            }
            var result: JSONValue
            if resume, let sessionID = state.sessionID {
                status = "Resuming saved Codex session…"
                result = try await client.rpc("session/load", ["sessionId": .string(sessionID)])
                guard generation == connection else { return }
            } else {
                status = "Starting synthetic Codex session…"
                result = try await client.rpc("session/new", [:])
                guard generation == connection else { return }
                guard let sessionID = result[acp: "sessionId"].acpString else { throw CodexExperimentError.message("Agent returned no session ID.") }
                try archiveCurrentSession()
                state = CodexExperimentState(sessionID: sessionID)
                pendingProposals = []; activities = []
            }
            models = result[acp: "models"][acp: "availableModels"].acpArray.compactMap {
                guard let id = $0[acp: "modelId"].acpString else { return nil }
                return (id, $0[acp: "name"].acpString ?? id)
            }
            let current = result[acp: "models"][acp: "currentModelId"].acpString ?? state.modelID
            selectedModel = current; state.modelID = current
            // Drain the load replay without feeding it into the locally saved transcript.
            let replay = try await client.events(after: -1)
            guard generation == connection else { return }
            cursor = replay[acp: "cursor"].acpInt ?? cursor
            connected = true; status = "Connected · Codex-managed ChatGPT session"; save()
            startPolling()
        } catch {
            guard generation == connection else { return }
            self.error = error.localizedDescription; status = "Connection failed. You can resume or start fresh."
        }
    }

    func fresh() async {
        guard !busy, let transport else { return }
        await connect(using: transport, resume: false)
    }

    func send(proposal: Bool = false) async {
        guard !busy, connected, let transport, let sessionID = state.sessionID else { return }
        let userText = proposal ? "Suggest one project update from the synthetic context. Keep it pending for review." : draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty, !selectedModel.isEmpty else { return }
        if proposal && !includeContext { error = "Include the synthetic context to generate an evidence-validated proposal."; return }
        busy = true; stopped = false; error = nil; permissions = []; phase = ""
        if proposal { pendingProposals = []; state.pendingProposalJSON = nil }
        let turn = UUID(); generation = turn
        do {
            if selectedModel != state.modelID {
                _ = try await transport.rpc("session/set_model", ["sessionId": .string(sessionID), "modelId": .string(selectedModel)])
                guard generation == turn else { return }
                if stopped { throw CancellationError() }
                state.modelID = selectedModel
            }
            var prompt = userText
            if includeContext {
                prompt += "\n\nContext added this turn (synthetic user-authored source, id=\(Self.evidenceID.uuidString), version=1):\n\(Self.syntheticContext)"
            }
            if proposal { prompt += try Self.proposalInstructions() }
            state.messages.append(CodexExperimentMessage(role: "user", text: userText, addedContext: includeContext))
            let reply = CodexExperimentMessage(role: "assistant", text: "", status: "streaming")
            assistantID = reply.id; state.messages.append(reply)
            state.contextWasSent = state.contextWasSent || includeContext
            if !proposal { draft = "" }
            status = proposal ? "Generating a pending proposal…" : "Codex is working…"
            save()
            let response = try await transport.rpc("session/prompt", ["sessionId": .string(sessionID), "prompt": .array([.object(["type": .string("text"), "text": .string(prompt)])])])
            // A final event poll closes the race between the last delta and the prompt response.
            try await pollOnce()
            guard generation == turn else { return }
            let cancelled = stopped || response[acp: "stopReason"].acpString == "cancelled"
            finishAssistant(cancelled ? "interrupted" : "complete")
            if proposal && !cancelled, let last = state.messages.last {
                pendingProposals = try Self.validateProposal(last.text)
                state.pendingProposalJSON = last.text
                status = "Validated pending proposal · no project changes applied"
            } else { status = cancelled ? "Stopped. Partial response retained." : "Response complete" }
        } catch {
            guard generation == turn else { return }
            // Preserve deltas emitted immediately before a failed prompt response.
            try? await pollOnce()
            guard generation == turn else { return }
            finishAssistant(stopped ? "interrupted" : "failed")
            self.error = error.localizedDescription
            status = "Turn ended. Partial response retained; nothing replayed."
        }
        if generation == turn { busy = false; assistantID = nil; permissions = []; save() }
    }

    func stop() async {
        if busy && assistantID == nil { disconnect(); return }
        guard busy, let transport, let sessionID = state.sessionID else { return }
        stopped = true; permissions = []; finishAssistant("interrupted"); save()
        do { _ = try await transport.rpc("session/cancel", ["sessionId": .string(sessionID)]); status = "Stop requested…" }
        catch { self.error = error.localizedDescription }
    }

    func respond(_ permission: CodexExperimentPermission, optionID: String) async {
        guard !stopped, permissions.contains(where: { $0.id == permission.id }), let transport else { return }
        do { try await transport.permission(id: permission.id, optionID: optionID); permissions.removeAll { $0.id == permission.id } }
        catch { self.error = error.localizedDescription }
    }

    func disconnect() {
        polling?.cancel(); polling = nil
        if busy, let transport, let sessionID = state.sessionID {
            Task { _ = try? await transport.rpc("session/cancel", ["sessionId": .string(sessionID)]) }
        }
        generation = UUID(); stopped = true; finishAssistant("interrupted"); assistantID = nil
        connected = false; busy = false; permissions = []; transport = nil; save()
        status = "Disconnected. Paste a helper pairing code to resume."
    }

    private func startPolling() {
        polling = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await self?.pollOnce()
                    try await Task.sleep(for: .milliseconds(150))
                } catch is CancellationError { break }
                catch {
                    guard !Task.isCancelled else { break }
                    guard let self else { break }
                    self.error = error.localizedDescription; self.disconnect(); break
                }
            }
        }
    }

    private func pollOnce() async throws {
        // Await the previous poll instead of issuing requests with overlapping cursors.
        while pollInFlight { try await Task.sleep(for: .milliseconds(20)) }
        guard let transport else { return }
        let connection = generation
        pollInFlight = true
        defer { pollInFlight = false }
        let events = try await transport.events(after: cursor)
        guard generation == connection, !Task.isCancelled else { return }
        for event in events[acp: "events"].acpArray { consume(event) }
        cursor = max(cursor, events[acp: "cursor"].acpInt ?? cursor)
        if busy { save() }
    }

    // Visible internally for deterministic lifecycle tests. Protocol replay never creates messages.
    func consume(_ event: JSONValue) {
        guard let sequence = event[acp: "seq"].acpInt, sequence > cursor else { return }
        cursor = sequence
        guard !event[acp: "replay"].acpBool else { return }
        let params = event[acp: "params"]
        if event[acp: "kind"].acpString == "error" {
            error = params[acp: "message"].acpString; disconnect(); return
        }
        guard !stopped, busy, params[acp: "sessionId"].acpString == state.sessionID else { return }
        if event[acp: "kind"].acpString == "permission", let id = event[acp: "id"].acpString {
            let options = params[acp: "options"].acpArray.compactMap { option -> CodexExperimentPermission.Option? in
                guard option[acp: "kind"].acpString != "allow_always", let id = option[acp: "optionId"].acpString else { return nil }
                return .init(id: id, name: option[acp: "name"].acpString ?? id)
            }
            permissions.append(.init(id: id, title: params[acp: "toolCall"][acp: "title"].acpString ?? "Agent permission", options: options))
            return
        }
        let update = params[acp: "update"]
        switch update[acp: "sessionUpdate"].acpString {
        case "agent_message_chunk":
            guard let id = assistantID, let index = state.messages.firstIndex(where: { $0.id == id }), let text = update[acp: "content"][acp: "text"].acpString else { return }
            let newPhase = update[acp: "_meta"][acp: "codex"][acp: "phase"].acpString ?? ""
            if !phase.isEmpty && !newPhase.isEmpty && phase != newPhase { state.messages[index].text += "\n\n" }
            phase = newPhase; state.messages[index].text += text
        case "tool_call", "tool_call_update":
            guard let id = update[acp: "toolCallId"].acpString else { return }
            let index = activities.firstIndex(where: { $0.id == id })
            let previous = index.map { activities[$0] }
            let activity = CodexExperimentActivity(id: id, title: update[acp: "title"].acpString ?? previous?.title ?? "Codex activity", kind: update[acp: "kind"].acpString ?? previous?.kind ?? "other", status: update[acp: "status"].acpString ?? previous?.status ?? "pending")
            if let index { activities[index] = activity } else { activities.append(activity) }
        default: break
        }
    }

    private func finishAssistant(_ status: String) {
        guard let id = assistantID, let index = state.messages.firstIndex(where: { $0.id == id }) else { return }
        state.messages[index].status = status
    }

    private func save() {
        guard !persistenceBlocked else { return }
        do {
            try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
        } catch { self.error = "Could not save experiment history: \(error.localizedDescription)" }
    }

    private func archiveCurrentSession() throws {
        guard state.sessionID != nil else { return }
        let directory = stateURL.deletingLastPathComponent().appending(path: "archives", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: directory.appending(path: "\(UUID()).json"), options: .atomic)
    }

    static func proposalInstructions() throws -> String {
        let schema = String(decoding: try ProjectOSCore.ProposalSchema.data(), as: UTF8.self)
        return "\n\nReturn ONLY one JSON object complying with the following production schema. Create exactly one open_question or research proposal, with an exact contiguous quote from synthetic source \(evidenceID.uuidString), sourceType source, version 1. A conditional preference is not a committed decision. Do not write files or apply any changes. Every schema field must be present (null when unused).\n\(schema)"
    }

    static func validateProposal(_ text: String) throws -> [ProjectOSCore.Proposal] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let json: String
        if trimmed.hasPrefix("```json\n"), trimmed.hasSuffix("```") { json = String(trimmed.dropFirst(8).dropLast(3)) }
        else if trimmed.hasPrefix("```\n"), trimmed.hasSuffix("```") { json = String(trimmed.dropFirst(4).dropLast(3)) }
        else { json = trimmed }
        let context = ProjectOSCore.ContextSnapshot(projectID: projectID, projectRevision: 0, providerID: "codex-acp", modelID: "experiment", configurationID: "synthetic", purpose: .proposals, selections: [
            ProjectOSCore.ContextSelection(kind: .source, referenceID: evidenceID, version: 1, label: "Synthetic user-authored source", text: syntheticContext)
        ])
        let result = try ProjectOSCore.ProposalValidator.validate(data: Data(json.utf8), projectID: projectID, jobID: UUID(), context: context, currentProjectRevision: 0, currentArtifacts: [])
        guard result.proposals.count == 1, result.proposals.allSatisfy({ !$0.evidence.isEmpty && $0.operation == .create && ["open_question", "research"].contains($0.kind.rawValue) }) else { throw CodexExperimentError.message("Experiment requires one question or research create proposal with exact synthetic evidence.") }
        return result.proposals
    }
}
