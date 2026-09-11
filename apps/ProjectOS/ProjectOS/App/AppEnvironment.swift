import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var projects: [ProjectRecord] = []
    @Published var selectedProject: ProjectRecord?
    @Published var section: WorkspaceSection = .overview
    @Published var sources: [SourceRecord] = []
    @Published var conversations: [ConversationRecord] = []
    @Published var selectedConversationID: UUID?
    @Published var messages: [MessageRecord] = []
    @Published var artifacts: [ArtifactRecord] = []
    @Published var proposals: [ProposalRecord] = []
    @Published var changes: [ChangeRecord] = []
    @Published var outcomes: [ReturnRecord] = []
    @Published var recommendation: RecommendationRecord?
    @Published var inferenceJobs: [InferenceJobRecord] = []
    @Published var draft = ""
    @Published var showCreateProject = false
    @Published var showAddSource = false
    @Published var showOutcome = false
    @Published var alertMessage: String?
    @Published var evidenceInspection: EvidenceInspection?
    @Published var isGenerating = false
    @Published var generationStatus = "Idle"
    @Published var contextSelection = ContextSelection()
    @Published var provider: ProviderChoice
    @Published var ollamaURL: String
    @Published var ollamaModel: String
    @Published var openRouterModel: String
    @Published var openRouterRoute: String
    @Published var contextWindowTokens: String
    @Published var maximumOutputTokens: String
    @Published var approvedSpendingCeilingUSD: String
    @Published var providerReadiness: ProviderReadiness = .unavailable

    private(set) var store: ProjectStore?
    private var activeTask: Task<Void, Never>?
    private var activeJobRecord: InferenceJobRecord?
    private var visitBaseline: Int?
    private var contextInitializedProjectID: UUID?
    private var lastExportReceipt: ProjectArchiveReceipt?
    private var started = false

    init() {
        let defaults = UserDefaults.standard
        provider = ProviderChoice(rawValue: defaults.string(forKey: "provider") ?? "") ?? .ollama
        ollamaURL = defaults.string(forKey: "ollamaURL") ?? "http://127.0.0.1:11434"
        ollamaModel = defaults.string(forKey: "ollamaModel") ?? ""
        openRouterModel = defaults.string(forKey: "openRouterModel") ?? ""
        openRouterRoute = defaults.string(forKey: "openRouterRoute") ?? ""
        let storedWindow = defaults.integer(forKey: "providerContextWindowTokens")
        contextWindowTokens = storedWindow > 0 ? String(storedWindow) : ""
        let storedOutput = defaults.integer(forKey: "providerMaximumOutputTokens")
        maximumOutputTokens = String(storedOutput > 0 ? storedOutput : 4096)
        approvedSpendingCeilingUSD = defaults.string(forKey: "openRouterApprovedSpendingCeilingUSD") ?? ""
    }

    func start() {
        guard !started else { return }
        started = true
        do {
            store = try ProjectStore(url: ProjectStore.defaultURL())
            try store?.markUnfinishedJobsInterrupted()
            try reloadLibrary()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func reloadLibrary() throws {
        projects = try store?.projects() ?? []
        if let selectedID = selectedProject?.id {
            selectedProject = projects.first { $0.id == selectedID }
        }
    }

    func createProject(name: String, summary: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Give the project a name."
            return
        }
        perform {
            let project = try requireStore().createProject(name: name, summary: summary)
            try reloadLibrary()
            showCreateProject = false
            openProject(project)
        }
    }

    func openProject(_ project: ProjectRecord) {
        if activeJobRecord?.projectID != nil, activeJobRecord?.projectID != project.id {
            stopGeneration()
        }
        if lastExportReceipt?.projectID != project.id { lastExportReceipt = nil }
        selectedProject = project
        section = .overview
        visitBaseline = project.previousVisitRevision
        contextSelection = ContextSelection()
        contextInitializedProjectID = nil
        selectedConversationID = nil
        refreshProject()
    }

    func closeProject() {
        completeVisit()
        stopGeneration()
        selectedProject = nil
        visitBaseline = nil
        try? reloadLibrary()
    }

    func completeVisit() {
        if let project = selectedProject {
            try? store?.markVisitBaseline(projectID: project.id, baseline: project.revision)
        }
    }

    func refreshProject() {
        guard let id = selectedProject?.id else { return }
        perform {
            try reloadLibrary()
            sources = try requireStore().sources(projectID: id)
            conversations = try requireStore().ensureConversations(projectID: id)
            if selectedConversationID.flatMap({ selected in conversations.first { $0.id == selected } }) == nil {
                selectedConversationID = conversations.first?.id
            }
            messages = try selectedConversationID.map { try requireStore().messages(projectID: id, conversationID: $0) } ?? []
            artifacts = try requireStore().artifacts(projectID: id)
            proposals = try requireStore().proposals(projectID: id)
            changes = try requireStore().changes(projectID: id)
            outcomes = try requireStore().outcomes(projectID: id)
            recommendation = try requireStore().recommendation(projectID: id)
            inferenceJobs = try requireStore().jobs(projectID: id).sorted { $0.createdAt > $1.createdAt }
            draft = try selectedConversationID.map { try requireStore().draft(projectID: id, conversationID: $0) } ?? ""
            let eligibleSourceIDs = Set(sources.map(\.id))
            let eligibleArtifactIDs = Set(artifacts.filter { $0.state != .removed && $0.state != .superseded }.map(\.id))
            if contextInitializedProjectID != id {
                contextSelection.sourceIDs = eligibleSourceIDs
                contextSelection.artifactIDs = eligibleArtifactIDs
                contextInitializedProjectID = id
            } else {
                contextSelection.sourceIDs.formIntersection(eligibleSourceIDs)
                contextSelection.artifactIDs.formIntersection(eligibleArtifactIDs)
            }
        }
    }

    func addSource(label: String, text: String) {
        guard let projectID = selectedProject?.id else { return }
        guard !label.isEmpty, !text.isEmpty else { alertMessage = "A label and pasted text are required."; return }
        perform {
            let source = try requireStore().addSource(projectID: projectID, label: label, text: text)
            sources = try requireStore().sources(projectID: projectID)
            contextSelection.sourceIDs.insert(source.id)
            showAddSource = false
        }
    }

    func updateProject(name: String, summary: String) {
        guard var project = selectedProject, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        perform {
            project = try requireStore().updateProjectDetails(projectID: project.id, expectedRevision: project.revision, name: name, summary: summary)
            selectedProject = project
            try reloadLibrary()
        }
    }

    func saveDraft() {
        guard let projectID = selectedProject?.id, let conversationID = selectedConversationID else { return }
        do { try store?.saveDraft(projectID: projectID, conversationID: conversationID, text: draft) }
        catch { alertMessage = error.localizedDescription }
    }

    func createConversation() {
        guard let projectID = selectedProject?.id else { return }
        perform {
            let conversation = try requireStore().createConversation(projectID: projectID)
            conversations.insert(conversation, at: 0)
            selectedConversationID = conversation.id
            messages = []
            draft = ""
        }
    }

    func selectConversation(_ id: UUID) {
        guard let projectID = selectedProject?.id, id != selectedConversationID else { return }
        saveDraft()
        perform {
            selectedConversationID = id
            messages = try requireStore().messages(projectID: projectID, conversationID: id)
            draft = try requireStore().draft(projectID: projectID, conversationID: id)
        }
    }

    var contextPreview: String {
        guard selectedProject != nil else { return "No project selected" }
        let sourceCount = sources.filter { contextSelection.sourceIDs.contains($0.id) }.count
        let artifactCount = artifacts.filter { contextSelection.artifactIDs.contains($0.id) }.count
        let messageCount = min(contextSelection.messageCount, messages.filter { $0.completion == .complete }.count)
        let boundary = provider == .ollama ? "On this Mac" : "External · may incur charges"
        let limit = Int(contextWindowTokens).map(String.init) ?? "unknown"
        return "\(provider.rawValue) · \(selectedModel.isEmpty ? "No model selected" : selectedModel) · \(boundary)\nDescription: \(contextSelection.includeDescription ? "included" : "excluded") · \(sourceCount) sources · \(artifactCount) accepted records · \(messageCount) complete messages\nConservative request bound: ≤\(estimatedRequestTokens) tokens · configured window: \(limit)"
    }

    var selectedModel: String { provider == .ollama ? ollamaModel : openRouterModel }

    var changesSincePreviousVisit: [ChangeRecord] {
        let baseline = visitBaseline ?? selectedProject?.previousVisitRevision ?? 0
        return changes.filter { $0.revision > baseline }
    }

    func sendMessage() {
        guard let project = selectedProject, let conversationID = selectedConversationID else { return }
        let userText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }
        guard validateContextBounds(extraText: userText) else { return }

        let userMessage = MessageRecord(id: UUID(), projectID: project.id, conversationID: conversationID, role: .user, text: userText, completion: .complete, createdAt: Date())
        let assistantID = UUID()
        do {
            try requireStore().saveMessage(userMessage)
            draft = ""
            try requireStore().saveDraft(projectID: project.id, conversationID: conversationID, text: "")
            messages.append(userMessage)
            conversations = try requireStore().conversations(projectID: project.id)
        } catch { alertMessage = error.localizedDescription; return }

        let frozen = makeFrozenContext(project: project)
        guard let appJobID = beginJob(purpose: "chat", context: frozen) else { return }
        let frozenConversationID = conversationID
        isGenerating = true
        generationStatus = "Generating with \(provider.rawValue)…"
        let configuration = currentProviderConfiguration
        activeTask = Task { [weak self] in
            guard let self else { return }
            var answer = ""
            do {
                let service = InferenceService(configuration: configuration)
                for try await event in service.chat(context: frozen, userMessage: userText) {
                    guard !Task.isCancelled else { throw CancellationError() }
                    switch event {
                    case .text(let token):
                        answer += token
                        let partial = MessageRecord(id: assistantID, projectID: project.id, conversationID: frozenConversationID, role: .assistant, text: answer, completion: .partial, createdAt: Date())
                        try self.requireStore().saveMessage(partial)
                        if self.selectedProject?.id == project.id, self.selectedConversationID == frozenConversationID { self.upsertMessage(partial) }
                    case .usage(let usage): self.recordTelemetry(usage: usage, metadata: nil, expectedID: appJobID)
                    case .completed(let metadata): self.recordTelemetry(usage: nil, metadata: metadata, expectedID: appJobID)
                    }
                }
                let completed = MessageRecord(id: assistantID, projectID: project.id, conversationID: frozenConversationID, role: .assistant, text: answer, completion: .complete, createdAt: Date())
                try self.requireStore().saveMessage(completed)
                if self.selectedProject?.id == project.id, self.selectedConversationID == frozenConversationID { self.upsertMessage(completed) }
                self.generationStatus = "Completed"
                self.finishActiveJob(.completed, expectedID: appJobID)
            } catch is CancellationError {
                let cancelled = MessageRecord(id: assistantID, projectID: project.id, conversationID: frozenConversationID, role: .assistant, text: answer, completion: .cancelled, createdAt: Date())
                try? self.requireStore().saveMessage(cancelled)
                if self.selectedProject?.id == project.id, self.selectedConversationID == frozenConversationID { self.upsertMessage(cancelled) }
                self.generationStatus = "Stopped · provider compute may continue"
                self.finishActiveJob(.cancelled, expectedID: appJobID)
            } catch {
                let failed = MessageRecord(id: assistantID, projectID: project.id, conversationID: frozenConversationID, role: .assistant, text: answer, completion: .failed, createdAt: Date())
                try? self.requireStore().saveMessage(failed)
                if self.selectedProject?.id == project.id, self.selectedConversationID == frozenConversationID { self.upsertMessage(failed) }
                self.alertMessage = error.localizedDescription
                self.generationStatus = "Failed · retry explicitly"
                self.finishActiveJob(.failed, expectedID: appJobID)
            }
            self.isGenerating = false
            self.activeTask = nil
        }
    }

    func stopGeneration() {
        activeTask?.cancel()
        finishActiveJob(.cancelled, expectedID: activeJobRecord?.id)
        activeTask = nil
        isGenerating = false
    }

    func suggestUpdates() {
        guard let project = selectedProject, validateContextBounds(extraText: "") else { return }
        let frozen = makeFrozenContext(project: project)
        guard let appJobID = beginJob(purpose: "proposals", context: frozen) else { return }
        let configuration = currentProviderConfiguration
        isGenerating = true
        generationStatus = "Requesting reviewable proposals…"
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let service = InferenceService(configuration: configuration)
                let generated = try await service.proposals(context: frozen)
                guard self.selectedProject?.id == project.id else { throw InferenceError.contextChanged }
                guard self.selectedProject?.revision == frozen.projectRevision else { throw InferenceError.contextChanged }
                let records = generated.proposals.map { item in
                    ProposalRecord(id: item.id, projectID: project.id, originatingRevision: frozen.projectRevision, operation: item.operation, targetID: item.targetID, expectedTargetRevision: item.expectedTargetRevision, kind: item.kind, title: item.title, content: item.content, rationale: item.rationale, decisionSubject: item.decisionSubject, proposedState: item.proposedState, certainty: item.certainty, limitations: item.limitations, evidence: item.evidence, relationships: item.relationships, dependencyIDs: item.dependencyIDs, lifecycle: .pending, createdAt: Date())
                }
                try self.requireStore().saveProposals(records, expectedProjectRevision: frozen.projectRevision)
                self.recordTelemetry(usage: generated.usage, metadata: generated.completionMetadata, expectedID: appJobID)
                self.proposals = try self.requireStore().proposals(projectID: project.id)
                self.generationStatus = records.isEmpty ? "No consequential updates suggested" : "\(records.count) proposals ready for review"
                self.finishActiveJob(.completed, expectedID: appJobID)
            } catch {
                self.alertMessage = error.localizedDescription
                self.generationStatus = "Proposal request failed · accepted state unchanged"
                self.finishActiveJob(.failed, expectedID: appJobID)
            }
            self.isGenerating = false
            self.activeTask = nil
        }
    }

    func suggestNextAction() {
        guard let project = selectedProject, !artifacts.isEmpty, validateContextBounds(extraText: "") else { return }
        let frozen = makeFrozenContext(project: project)
        guard let appJobID = beginJob(purpose: "nextAction", context: frozen) else { return }
        let configuration = currentProviderConfiguration
        isGenerating = true
        generationStatus = "Suggesting a revision-bound next action..."
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let suggestion = try await InferenceService(configuration: configuration).nextAction(context: frozen)
                guard self.selectedProject?.id == project.id,
                      self.selectedProject?.revision == frozen.projectRevision else { throw InferenceError.contextChanged }
                let record = RecommendationRecord(id: suggestion.id, projectID: project.id, text: suggestion.text, supportingRecords: suggestion.supportingRecords.map { RecommendationSupport(id: $0.id, version: Int($0.version)) }, uncertainty: suggestion.uncertainty, originatingRevision: Int(suggestion.originatingRevision), createdAt: suggestion.createdAt, isDismissed: false)
                try self.requireStore().saveRecommendation(record)
                self.recordTelemetry(usage: suggestion.usage, metadata: suggestion.completionMetadata, expectedID: appJobID)
                self.recommendation = record
                self.generationStatus = "Next action ready"
                self.finishActiveJob(.completed, expectedID: appJobID)
            } catch {
                self.alertMessage = error.localizedDescription
                self.generationStatus = "Next-action request failed"
                self.finishActiveJob(.failed, expectedID: appJobID)
            }
            self.isGenerating = false
            self.activeTask = nil
        }
    }

    func dismissRecommendation() {
        guard var recommendation else { return }
        recommendation.isDismissed = true
        perform { try requireStore().saveRecommendation(recommendation); self.recommendation = recommendation }
    }

    func accept(_ proposal: ProposalRecord, title: String? = nil, content: String? = nil) {
        perform {
            try requireStore().acceptProposal(proposal.id, editedTitle: title, editedContent: content)
            refreshProject()
        }
    }

    func setProposal(_ proposal: ProposalRecord, lifecycle: ProposalLifecycle) {
        perform { try requireStore().setProposal(proposal.id, lifecycle: lifecycle); refreshProject() }
    }

    func markAsReplacement(_ proposal: ProposalRecord, prior: ArtifactRecord) {
        perform {
            try requireStore().markProposalAsSuperseding(proposal.id, priorDecisionID: prior.id)
            refreshProject()
        }
    }

    func replacementCandidate(for proposal: ProposalRecord) -> ArtifactRecord? {
        guard proposal.kind == .decision, let subject = normalizedSubject(proposal.decisionSubject) else { return nil }
        return artifacts.first {
            $0.kind == .decision && $0.state == .current && normalizedSubject($0.decisionSubject) == subject
        }
    }

    func dependencyClosure(for proposal: ProposalRecord) -> [ProposalRecord] {
        let byID = Dictionary(uniqueKeysWithValues: proposals.map { ($0.id, $0) })
        var result: [ProposalRecord] = []
        var visited = Set<UUID>()
        func visit(_ id: UUID) {
            guard visited.insert(id).inserted, let item = byID[id] else { return }
            item.dependencyIDs.forEach(visit)
            result.append(item)
        }
        proposal.dependencyIDs.forEach(visit)
        return result
    }

    func inspectEvidence(_ evidence: EvidenceRecord) {
        guard let projectID = selectedProject?.id else { return }
        do {
            if evidence.sourceType == "message" {
                guard evidence.version == 1,
                      let message = try requireStore().messages(projectID: projectID).first(where: { $0.id == evidence.sourceID }),
                      message.text.range(of: evidence.quote) != nil else { throw ProjectStoreError.notFound("Retained evidence message") }
                evidenceInspection = EvidenceInspection(id: evidence.id, label: message.role == .user ? "User message" : "Assistant message", version: 1, fullText: message.text, quote: evidence.quote, aiAuthored: message.role == .assistant)
            } else {
                guard let source = sources.first(where: { $0.id == evidence.sourceID && $0.version == evidence.version }),
                      source.text.range(of: evidence.quote) != nil else { throw ProjectStoreError.notFound("Retained evidence source version") }
                evidenceInspection = EvidenceInspection(id: evidence.id, label: source.label, version: source.version, fullText: source.text, quote: evidence.quote, aiAuthored: evidence.aiAuthored)
            }
        } catch { alertMessage = error.localizedDescription }
    }

    func saveArtifact(_ artifact: ArtifactRecord, summary: String) {
        guard let revision = selectedProject?.revision else { return }
        perform { try requireStore().saveArtifact(artifact, expectedProjectRevision: revision, summary: summary); refreshProject() }
    }

    func createArtifact(kind: ArtifactKind, title: String, content: String, rationale: String, decisionSubject: String) {
        guard let project = selectedProject else { return }
        let state: ArtifactState = kind == .task || kind == .openQuestion ? .open : .current
        let artifact = ArtifactRecord(id: UUID(), projectID: project.id, kind: kind, title: title, content: content, state: state, rationale: rationale.isEmpty ? nil : rationale, decisionSubject: decisionSubject.isEmpty ? nil : decisionSubject, evidence: [], version: 0, updatedAt: Date())
        saveArtifact(artifact, summary: "Added \(kind.rawValue): \(title)")
    }

    func removeArtifact(_ artifact: ArtifactRecord) {
        var removed = artifact
        removed.state = .removed
        saveArtifact(removed, summary: "Removed \(artifact.kind.rawValue): \(artifact.title)")
    }

    func linkArtifact(_ artifact: ArtifactRecord, to targetID: UUID, type: String) {
        guard artifact.id != targetID, artifacts.contains(where: { $0.id == targetID && $0.projectID == artifact.projectID }) else {
            alertMessage = "Choose another record in this project as the relationship target."
            return
        }
        var linked = artifact
        if !linked.relationships.contains(where: { $0.type == type && $0.targetArtifactID == targetID }) {
            linked.relationships.append(TypedRelationship(id: UUID(), type: type, targetArtifactID: targetID, targetProposalID: nil))
        }
        saveArtifact(linked, summary: "Linked \(artifact.title) \(type) another record")
    }

    func undoLatest() { guard let id = selectedProject?.id else { return }; perform { try requireStore().undoLatest(projectID: id); refreshProject() } }

    func saveOutcome(_ outcome: ReturnRecord) { perform { try requireStore().saveOutcome(outcome); refreshProject(); showOutcome = false } }

    func exportSelectedProject() {
        guard let project = selectedProject, let store else { return }
        let panel = NSSavePanel()
        panel.title = "Export ProjectOS Project"
        panel.nameFieldStringValue = "\(project.name).projectos"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let receipt = try await ProjectArchiveService().exportProject(id: project.id, from: store, to: url)
                lastExportReceipt = receipt
                alertMessage = "Export verified at \(receipt.archiveURL.path)."
            } catch { alertMessage = error.localizedDescription }
        }
    }

    func restoreProject() {
        guard let store else { return }
        let panel = NSOpenPanel()
        panel.title = "Restore ProjectOS Archive"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let receipt = try await ProjectArchiveService().restoreProject(from: url, into: store)
                try reloadLibrary()
                if let restored = projects.first(where: { $0.id == receipt.restoredProjectID }) { openProject(restored) }
                alertMessage = "Restored as a separate project copy."
            } catch { alertMessage = error.localizedDescription }
        }
    }

    func deleteSelectedProject(typedConfirmation: String) {
        guard let project = selectedProject, let store else { return }
        stopGeneration()
        let verifiedExport = lastExportReceipt.flatMap { $0.projectID == project.id && $0.revision == project.revision ? $0 : nil }
        let request = ProjectDeletionRequest(projectID: project.id, projectName: project.name, typedConfirmation: typedConfirmation, exportOfferWasPresented: true, exportDecision: verifiedExport.map(ProjectDeletionExportDecision.exported) ?? .declined)
        Task {
            do {
                _ = try await ProjectDeletionCoordinator().deleteProject(request, store: store, jobs: AppDeletionJobs())
                selectedProject = nil
                lastExportReceipt = nil
                visitBaseline = nil
                try reloadLibrary()
            } catch { alertMessage = error.localizedDescription }
        }
    }

    func saveProviderSettings() {
        let defaults = UserDefaults.standard
        defaults.set(provider.rawValue, forKey: "provider")
        defaults.set(ollamaURL, forKey: "ollamaURL")
        defaults.set(ollamaModel, forKey: "ollamaModel")
        defaults.set(openRouterModel, forKey: "openRouterModel")
        defaults.set(openRouterRoute, forKey: "openRouterRoute")
        if let window = Int(contextWindowTokens), window > 0 { defaults.set(window, forKey: "providerContextWindowTokens") }
        else { defaults.removeObject(forKey: "providerContextWindowTokens") }
        if let output = Int(maximumOutputTokens), output > 0 { defaults.set(output, forKey: "providerMaximumOutputTokens") }
        else { defaults.removeObject(forKey: "providerMaximumOutputTokens") }
        if approvedSpendingCeilingUSD.isEmpty { defaults.removeObject(forKey: "openRouterApprovedSpendingCeilingUSD") }
        else { defaults.set(approvedSpendingCeilingUSD, forKey: "openRouterApprovedSpendingCeilingUSD") }
        providerReadiness = .unverified
    }

    func saveOpenRouterKey(_ key: String) async -> Bool {
        do {
            try await KeychainCredentialStore().save(key, account: "openrouter-api-key")
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func removeOpenRouterKey() {
        Task {
            do { try await KeychainCredentialStore().delete(account: "openrouter-api-key") }
            catch { alertMessage = error.localizedDescription }
        }
    }

    func testProvider() {
        let configuration = currentProviderConfiguration
        Task {
            do {
                let service = InferenceService(configuration: configuration)
                try await service.connectivityTest()
                providerReadiness = .connected
                generationStatus = "Connected, not quality-qualified"
            } catch {
                providerReadiness = .unavailable
                alertMessage = error.localizedDescription
            }
        }
    }

    private var currentProviderConfiguration: InferenceConfiguration {
        InferenceConfiguration(provider: provider, ollamaURL: ollamaURL, model: selectedModel, openRouterRoute: openRouterRoute)
    }

    private func makeFrozenContext(project: ProjectRecord) -> FrozenProjectContext {
        let selectedSources = sources.filter { contextSelection.sourceIDs.contains($0.id) }
        let selectedArtifacts = artifacts.filter { contextSelection.artifactIDs.contains($0.id) && $0.state != .removed && $0.state != .superseded }
        let completeMessages = messages.filter { $0.completion == .complete }.suffix(contextSelection.messageCount)
        return FrozenProjectContext(projectID: project.id, projectRevision: project.revision, projectName: project.name, projectDescription: contextSelection.includeDescription ? project.summary : nil, sources: selectedSources, artifacts: selectedArtifacts, messages: Array(completeMessages), provider: provider, model: selectedModel)
    }

    private func validateContextBounds(extraText: String) -> Bool {
        guard !selectedModel.isEmpty else { alertMessage = "Choose a model in Settings before sending."; return false }
        guard let limit = Int(contextWindowTokens), limit > 0 else { alertMessage = "Enter the selected model's documented context window in Settings before sending."; return false }
        let estimated = estimatedRequestTokens + extraText.utf8.count
        guard estimated <= limit else { alertMessage = "The selected request may require up to \(estimated) tokens, above the configured \(limit)-token window. Narrow sources, artifacts, or message range before sending."; return false }
        return true
    }

    private var estimatedRequestTokens: Int {
        let output = max(1, Int(maximumOutputTokens) ?? 4_096)
        // Mirrors the provider's fail-closed one-byte-per-token bound and
        // reserves framing/schema instructions before transport validation.
        return contextPreviewTextLength + output + 8_192
    }

    private var contextPreviewTextLength: Int {
        (contextSelection.includeDescription ? selectedProject?.summary.count ?? 0 : 0)
            + sources.filter { contextSelection.sourceIDs.contains($0.id) }.reduce(0) { $0 + $1.text.count }
            + artifacts.filter { contextSelection.artifactIDs.contains($0.id) }.reduce(0) { $0 + $1.content.count + $1.title.count }
            + messages.filter { $0.completion == .complete }.suffix(contextSelection.messageCount).reduce(0) { $0 + $1.text.count }
    }

    private func upsertMessage(_ message: MessageRecord) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) { messages[index] = message }
        else { messages.append(message) }
    }

    private func beginJob(purpose: String, context: FrozenProjectContext) -> UUID? {
        let job = InferenceJobRecord(id: UUID(), contextID: UUID(), projectID: context.projectID, sourceRevision: context.projectRevision, provider: context.provider.rawValue, model: context.model, configuredUpstreamRoute: context.provider == .openRouter ? openRouterRoute : nil, purpose: purpose, sourceIDs: context.sources.map(\.id), artifactIDs: context.artifacts.map(\.id), messageIDs: context.messages.map(\.id), createdAt: Date(), status: .running)
        do {
            try requireStore().saveJob(job)
            activeJobRecord = job
            upsertJob(job)
            return job.id
        } catch {
            alertMessage = "Inference did not start because its recovery record could not be saved. \(error.localizedDescription)"
            return nil
        }
    }

    private func finishActiveJob(_ status: InferenceJobStatus, expectedID: UUID?) {
        guard var job = activeJobRecord, expectedID == job.id else { return }
        job.status = status
        try? store?.saveJob(job)
        upsertJob(job)
        activeJobRecord = nil
    }

    private func recordTelemetry(usage: AIUsage?, metadata: AICompletionMetadata?, expectedID: UUID) {
        guard var job = activeJobRecord, job.id == expectedID else { return }
        if let usage {
            job.inputTokens = usage.inputTokens
            job.outputTokens = usage.outputTokens
            job.cost = usage.cost
            job.currency = usage.currency
        }
        if let metadata {
            job.actualModel = metadata.modelID
            job.actualUpstreamProvider = metadata.upstreamProvider
        }
        do {
            try store?.saveJob(job)
            activeJobRecord = job
            upsertJob(job)
            if let cost = job.cost { generationStatus = "Generating · returned cost \(cost) \(job.currency ?? "")" }
            else if usage != nil { generationStatus = "Generating · usage returned; cost unknown" }
        } catch { alertMessage = error.localizedDescription }
    }

    private func upsertJob(_ job: InferenceJobRecord) {
        if let index = inferenceJobs.firstIndex(where: { $0.id == job.id }) { inferenceJobs[index] = job }
        else { inferenceJobs.insert(job, at: 0) }
    }

    private func requireStore() throws -> ProjectStore {
        guard let store else { throw ProjectStoreError.database("The local store is unavailable.") }
        return store
    }

    private func normalizedSubject(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { alertMessage = error.localizedDescription }
    }
}

private struct AppDeletionJobs: ProjectDeletionJobCancelling {
    func cancelJobsForDeletion(projectID: UUID) async throws {
        // AppEnvironment synchronously cancels and detaches its sole project task
        // before the coordinator creates the store fence. Late store writes are fenced.
    }
}
