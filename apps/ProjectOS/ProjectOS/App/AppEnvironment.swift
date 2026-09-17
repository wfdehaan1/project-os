import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var projects: [ProjectRecord] = []
    @Published var selectedProject: ProjectRecord?
    @Published var destination: WorkspaceDestination = .overview
    /// Where the Project Library is, when no project is open.
    @Published var libraryDestination: LibraryDestination = .projects
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
    /// The provider request in flight, or the one that just ended.
    @Published private(set) var activity: GenerationActivity?
    var isGenerating: Bool { activity?.isRunning == true }
    @Published var contextSelection = ContextSelection()
    @Published var provider: ProviderChoice
    @Published var ollamaURL: String {
        didSet {
            guard ollamaURL != oldValue else { return }
            installedOllamaModels = []
            ollamaModelLookupStatus = "Not looked up"
        }
    }
    @Published var ollamaModel: String
    /// Filled only by an explicit lookup; empty means "not looked up".
    @Published var installedOllamaModels: [String] = []
    @Published var ollamaModelLookupStatus = "Not looked up"
    @Published var isLookingUpOllamaModels = false
    @Published var openRouterModel: String
    @Published var openRouterRoute: String
    @Published var contextWindowTokens: String
    @Published var maximumOutputTokens: String
    @Published var approvedSpendingCeilingUSD: String
    @Published var providerReadiness: ProviderReadiness = .unavailable
    /// The SearXNG that serves web research, on this Mac.
    @Published var searxngURL: String {
        didSet {
            guard searxngURL != oldValue else { return }
            searxngStatus = "Not tested"
        }
    }
    @Published var searxngStatus = "Not tested"
    @Published var isTestingSearXNG = false

    /// Appearance and theme are independent global preferences. Appearance
    /// follows macOS until the person chooses otherwise.
    @Published var appearance: AppearancePreference { didSet { persistAppearance() } }
    @Published var themePreset: ThemePreset { didSet { persistThemePreset() } }

    /// Deterministic Pile Cover composition per project, so the Project Library
    /// can draw a cover without every card querying the store itself.
    @Published private(set) var projectCovers: [UUID: PileCoverSpec] = [:]

    private(set) var store: ProjectStore?
    private var activeTask: Task<Void, Never>?
    private var activeJobRecord: InferenceJobRecord?
    private var visitBaseline: Int?
    private var contextInitializedProjectID: UUID?
    /// Context choices per conversation for this session, so each thread keeps
    /// its own focus. A conversation without an entry starts from its default.
    private var contextSelections: [UUID: ContextSelection] = [:]
    private var lastExportReceipt: ProjectArchiveReceipt?
    private var started = false

    init() {
        let defaults = UserDefaults.standard
        provider = ProviderChoice(rawValue: defaults.string(forKey: "provider") ?? "") ?? .ollama
        ollamaURL = defaults.string(forKey: "ollamaURL") ?? "http://127.0.0.1:11434"
        ollamaModel = defaults.string(forKey: "ollamaModel") ?? ""
        openRouterModel = defaults.string(forKey: "openRouterModel") ?? ""
        openRouterRoute = defaults.string(forKey: "openRouterRoute") ?? ""
        searxngURL = defaults.string(forKey: "searxngURL") ?? SearXNGClient.defaultURL
        let storedWindow = defaults.integer(forKey: "providerContextWindowTokens")
        contextWindowTokens = storedWindow > 0 ? String(storedWindow) : ""
        let storedOutput = defaults.integer(forKey: "providerMaximumOutputTokens")
        maximumOutputTokens = String(storedOutput > 0 ? storedOutput : 4096)
        approvedSpendingCeilingUSD = defaults.string(forKey: "openRouterApprovedSpendingCeilingUSD") ?? ""
        appearance = AppearancePreference(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        themePreset = ThemePreset(rawValue: defaults.string(forKey: "themePreset") ?? "") ?? .default
    }

    private func persistAppearance() {
        UserDefaults.standard.set(appearance.rawValue, forKey: "appearance")
    }

    private func persistThemePreset() {
        UserDefaults.standard.set(themePreset.rawValue, forKey: "themePreset")
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
        try reloadProjectCovers()
    }

    /// Recomposes every project's cover from local state. Composition is pure
    /// and offline; nothing here contacts a provider.
    private func reloadProjectCovers() throws {
        guard let store else { projectCovers = [:]; return }
        var covers: [UUID: PileCoverSpec] = [:]
        for project in projects {
            covers[project.id] = PileCoverComposer.spec(
                artifacts: try store.artifacts(projectID: project.id),
                proposals: try store.proposals(projectID: project.id),
                changes: try store.changes(projectID: project.id)
            )
        }
        projectCovers = covers
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
        if activity?.projectID != project.id { activity = nil }
        if lastExportReceipt?.projectID != project.id { lastExportReceipt = nil }
        selectedProject = project
        destination = .overview
        visitBaseline = project.previousVisitRevision
        contextSelection = ContextSelection()
        contextInitializedProjectID = nil
        selectedConversationID = nil
        refreshProject()
    }

    func closeProject() {
        completeVisit()
        stopGeneration()
        activity = nil
        selectedProject = nil
        visitBaseline = nil
        // Leaving a project returns to the projects themselves, not to whatever
        // library page was open last.
        libraryDestination = .projects
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
                contextSelections = [:]
                contextSelection = defaultContextSelection(for: selectedConversation)
                contextInitializedProjectID = id
            } else {
                contextSelection.sourceIDs.formIntersection(eligibleSourceIDs)
                contextSelection.artifactIDs.formIntersection(eligibleArtifactIDs)
                // A research conversation always carries its subject.
                if let research = linkedResearch { contextSelection.artifactIDs.insert(research.id) }
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

    /// Keeps a page the model read as a project source, exactly as it was read.
    /// Only then can a record quote it, and the origin keeps the way back to
    /// the live page.
    func saveWebPageAsSource(_ page: WebPageSnapshot) {
        guard let projectID = selectedProject?.id, savedSource(for: page) == nil else { return }
        perform {
            let source = try requireStore().addSource(
                projectID: projectID,
                label: page.title,
                text: page.text,
                origin: page.origin
            )
            sources = try requireStore().sources(projectID: projectID)
            contextSelection.sourceIDs.insert(source.id)
        }
    }

    /// The source already kept from this exact retrieval, if there is one.
    func savedSource(for page: WebPageSnapshot) -> SourceRecord? {
        sources.first { $0.origin?.matches(page) == true }
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
        perform { try openNewConversation(projectID: projectID, researchID: nil) }
    }

    func selectConversation(_ id: UUID) {
        guard let projectID = selectedProject?.id, id != selectedConversationID else { return }
        saveDraft()
        perform {
            let previousID = selectedConversationID
            selectedConversationID = id
            switchContextSelection(from: previousID, to: id)
            messages = try requireStore().messages(projectID: projectID, conversationID: id)
            draft = try requireStore().draft(projectID: projectID, conversationID: id)
        }
    }

    func openConversation(_ id: UUID) {
        selectConversation(id)
        show(.conversation)
    }

    /// Turns web research on or off for the open conversation. The choice is
    /// remembered with the conversation, not with the session.
    func setWebResearch(_ enabled: Bool) {
        guard provider == .ollama || !enabled else { return }
        guard let projectID = selectedProject?.id, let conversationID = selectedConversationID else { return }
        perform {
            let updated = try requireStore().setWebResearch(enabled, conversationID: conversationID, projectID: projectID)
            if let index = conversations.firstIndex(where: { $0.id == updated.id }) { conversations[index] = updated }
        }
    }

    /// Opens a new conversation about a research item, focused on that item.
    /// Starting from Open moves the research to In progress; a conversation on
    /// research already under way or done leaves its status alone.
    func startResearchConversation(for research: ArtifactRecord) {
        guard let project = selectedProject, research.kind == .research, research.state != .removed else { return }
        perform {
            if research.state == .open {
                var started = research
                started.state = .inProgress
                try requireStore().saveArtifact(started, expectedProjectRevision: project.revision, summary: "Started Research: \(research.title)")
                refreshProject()
            }
            try openNewConversation(projectID: project.id, researchID: research.id)
            show(.conversation)
        }
    }

    func markResearchDone(_ research: ArtifactRecord) {
        guard research.kind == .research else { return }
        var done = research
        done.state = .done
        saveArtifact(done, summary: "Completed Research: \(research.title)")
    }

    private func openNewConversation(projectID: UUID, researchID: UUID?) throws {
        let conversation = try requireStore().createConversation(projectID: projectID, researchID: researchID)
        conversations.insert(conversation, at: 0)
        let previousID = selectedConversationID
        selectedConversationID = conversation.id
        switchContextSelection(from: previousID, to: conversation.id)
        messages = []
        draft = ""
    }

    /// Keeps the outgoing conversation's context choices and restores the
    /// incoming one's, or its default when it has none yet.
    private func switchContextSelection(from previousID: UUID?, to nextID: UUID) {
        if let previousID { contextSelections[previousID] = contextSelection }
        contextSelection = contextSelections[nextID] ?? defaultContextSelection(for: conversations.first { $0.id == nextID })
    }

    /// A research conversation starts from its research item alone; any other
    /// conversation starts from everything accepted plus every source.
    private func defaultContextSelection(for conversation: ConversationRecord?) -> ContextSelection {
        let eligibleArtifactIDs = Set(artifacts.filter { $0.state != .removed && $0.state != .superseded }.map(\.id))
        if let researchID = conversation?.researchID {
            return ContextSelection(includeDescription: false, sourceIDs: [], artifactIDs: eligibleArtifactIDs.intersection([researchID]))
        }
        return ContextSelection(sourceIDs: Set(sources.map(\.id)), artifactIDs: eligibleArtifactIDs)
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

        // Web research needs a reachable SearXNG address before anything is
        // saved, so a misconfigured one fails before the question is sent.
        let webResearch: WebResearchToolbox?
        if usesWebResearch {
            do { webResearch = try makeWebResearchToolbox(userMessage: userText) }
            catch { alertMessage = error.localizedDescription; return }
        } else {
            webResearch = nil
        }

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
        guard let appJobID = beginJob(purpose: .chat, context: frozen, usesWebResearch: webResearch != nil) else { return }
        let frozenConversationID = conversationID
        let configuration = currentProviderConfiguration
        activeTask = Task { [weak self] in
            guard let self else { return }
            var answer = ""
            var research: [WebResearchStep] = []
            /// The reply as it stands, with the research that produced it.
            func reply(_ completion: MessageCompletion) -> MessageRecord {
                let trail = completion == .partial ? research : research.map { $0.interrupted() }
                return MessageRecord(id: assistantID, projectID: project.id, conversationID: frozenConversationID, role: .assistant, text: answer, completion: completion, createdAt: Date(), research: trail.isEmpty ? nil : trail)
            }
            do {
                let service = InferenceService(configuration: configuration)
                for try await event in service.chat(context: frozen, userMessage: userText, webResearch: webResearch) {
                    guard !Task.isCancelled else { throw CancellationError() }
                    switch event {
                    case .phase(let phase): self.advanceActivity(to: phase, expectedID: appJobID)
                    case .text(let token):
                        self.advanceActivity(to: .receiving, expectedID: appJobID)
                        answer += token
                        let partial = reply(.partial)
                        try self.requireStore().saveMessage(partial)
                        if self.selectedProject?.id == project.id, self.selectedConversationID == frozenConversationID { self.upsertMessage(partial) }
                    case .research(let step):
                        if let index = research.firstIndex(where: { $0.id == step.id }) { research[index] = step }
                        else { research.append(step) }
                        self.noteResearch(step, expectedID: appJobID)
                        let partial = reply(.partial)
                        try self.requireStore().saveMessage(partial)
                        if self.selectedProject?.id == project.id, self.selectedConversationID == frozenConversationID { self.upsertMessage(partial) }
                    case .usage(let usage): self.recordTelemetry(usage: usage, metadata: nil, expectedID: appJobID)
                    case .completed(let metadata): self.recordTelemetry(usage: nil, metadata: metadata, expectedID: appJobID)
                    }
                }
                let completed = reply(.complete)
                try self.requireStore().saveMessage(completed)
                if self.selectedProject?.id == project.id, self.selectedConversationID == frozenConversationID { self.upsertMessage(completed) }
                self.finishActivity(.completed("Reply complete"), expectedID: appJobID)
                self.finishActiveJob(.completed, expectedID: appJobID)
            } catch is CancellationError {
                let cancelled = reply(.cancelled)
                try? self.requireStore().saveMessage(cancelled)
                if self.selectedProject?.id == project.id, self.selectedConversationID == frozenConversationID { self.upsertMessage(cancelled) }
                self.finishActivity(.stopped, expectedID: appJobID)
                self.finishActiveJob(.cancelled, expectedID: appJobID)
            } catch {
                let failed = reply(.failed)
                try? self.requireStore().saveMessage(failed)
                if self.selectedProject?.id == project.id, self.selectedConversationID == frozenConversationID { self.upsertMessage(failed) }
                self.alertMessage = error.localizedDescription
                self.finishActivity(.failed(error.localizedDescription), expectedID: appJobID)
                self.finishActiveJob(.failed, expectedID: appJobID)
            }
            self.activeTask = nil
        }
    }

    func stopGeneration() {
        activeTask?.cancel()
        finishActiveJob(.cancelled, expectedID: activeJobRecord?.id)
        if let id = activity?.id { finishActivity(.stopped, expectedID: id) }
        activeTask = nil
    }

    /// Clears an ended request from the sidebar once it has been read.
    func dismissActivity() {
        guard activity?.isRunning == false else { return }
        activity = nil
    }

    func suggestUpdates() {
        guard let project = selectedProject, validateContextBounds(extraText: "") else { return }
        let frozen = makeFrozenContext(project: project)
        guard let appJobID = beginJob(purpose: .proposals, context: frozen) else { return }
        let configuration = currentProviderConfiguration
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let service = InferenceService(configuration: configuration)
                let generated = try await service.proposals(context: frozen, progress: self.progress(for: appJobID))
                guard self.selectedProject?.id == project.id else { throw InferenceError.contextChanged }
                guard self.selectedProject?.revision == frozen.projectRevision else { throw InferenceError.contextChanged }
                let records = generated.proposals.map { item in
                    ProposalRecord(id: item.id, projectID: project.id, originatingRevision: frozen.projectRevision, operation: item.operation, targetID: item.targetID, expectedTargetRevision: item.expectedTargetRevision, kind: item.kind, title: item.title, content: item.content, rationale: item.rationale, decisionSubject: item.decisionSubject, proposedState: item.proposedState, certainty: item.certainty, limitations: item.limitations, evidence: item.evidence, relationships: item.relationships, dependencyIDs: item.dependencyIDs, lifecycle: .pending, createdAt: Date())
                }
                self.advanceActivity(to: .saving, expectedID: appJobID)
                try self.requireStore().saveProposals(records, expectedProjectRevision: frozen.projectRevision)
                self.recordTelemetry(usage: generated.usage, metadata: generated.completionMetadata, expectedID: appJobID)
                self.proposals = try self.requireStore().proposals(projectID: project.id)
                let summary = records.isEmpty ? "No consequential updates suggested" : "\(records.count) proposals ready for review"
                self.finishActivity(.completed(summary), expectedID: appJobID)
                self.finishActiveJob(.completed, expectedID: appJobID)
            } catch {
                self.alertMessage = error.localizedDescription
                self.finishActivity(.failed(error.localizedDescription), expectedID: appJobID)
                self.finishActiveJob(.failed, expectedID: appJobID)
            }
            self.activeTask = nil
        }
    }

    func suggestNextAction() {
        guard let project = selectedProject, !artifacts.isEmpty, validateContextBounds(extraText: "") else { return }
        let frozen = makeFrozenContext(project: project)
        guard let appJobID = beginJob(purpose: .nextAction, context: frozen) else { return }
        let configuration = currentProviderConfiguration
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let suggestion = try await InferenceService(configuration: configuration).nextAction(context: frozen, progress: self.progress(for: appJobID))
                guard self.selectedProject?.id == project.id,
                      self.selectedProject?.revision == frozen.projectRevision else { throw InferenceError.contextChanged }
                self.advanceActivity(to: .saving, expectedID: appJobID)
                let record = RecommendationRecord(id: suggestion.id, projectID: project.id, text: suggestion.text, supportingRecords: suggestion.supportingRecords.map { RecommendationSupport(id: $0.id, version: Int($0.version)) }, uncertainty: suggestion.uncertainty, originatingRevision: Int(suggestion.originatingRevision), createdAt: suggestion.createdAt, isDismissed: false)
                try self.requireStore().saveRecommendation(record)
                self.recordTelemetry(usage: suggestion.usage, metadata: suggestion.completionMetadata, expectedID: appJobID)
                self.recommendation = record
                self.finishActivity(.completed("Next action ready"), expectedID: appJobID)
                self.finishActiveJob(.completed, expectedID: appJobID)
            } catch {
                self.alertMessage = error.localizedDescription
                self.finishActivity(.failed(error.localizedDescription), expectedID: appJobID)
                self.finishActiveJob(.failed, expectedID: appJobID)
            }
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
                evidenceInspection = EvidenceInspection(id: evidence.id, label: source.label, version: source.version, fullText: source.text, quote: evidence.quote, aiAuthored: evidence.aiAuthored, origin: source.origin)
            }
        } catch { alertMessage = error.localizedDescription }
    }

    func saveArtifact(_ artifact: ArtifactRecord, summary: String) {
        guard let revision = selectedProject?.revision else { return }
        perform { try requireStore().saveArtifact(artifact, expectedProjectRevision: revision, summary: summary); refreshProject() }
    }

    func createArtifact(kind: ArtifactKind, title: String, content: String, rationale: String, decisionSubject: String) {
        guard let project = selectedProject else { return }
        let artifact = ArtifactRecord(id: UUID(), projectID: project.id, kind: kind, title: title, content: content, state: kind.initialState, rationale: rationale.isEmpty ? nil : rationale, decisionSubject: decisionSubject.isEmpty ? nil : decisionSubject, evidence: [], version: 0, updatedAt: Date())
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
        defaults.set(searxngURL, forKey: "searxngURL")
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

    /// Asks the local Ollama which models are installed. Only ever runs when
    /// the person presses the lookup button in Settings.
    func findInstalledOllamaModels() {
        guard let url = URL(string: ollamaURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            alertMessage = "The Ollama URL is invalid."
            return
        }
        let requestedURL = ollamaURL
        isLookingUpOllamaModels = true
        ollamaModelLookupStatus = "Looking up…"
        Task {
            defer { isLookingUpOllamaModels = false }
            do {
                let models = try await OllamaAdapter.installedModels(at: url)
                // The URL was edited while the lookup ran; this list belongs to the old one.
                guard ollamaURL == requestedURL else { return }
                installedOllamaModels = models
                ollamaModelLookupStatus = switch models.count {
                case 0: "No local models installed"
                case 1: "1 local model found"
                default: "\(models.count) local models found"
                }
            } catch {
                guard ollamaURL == requestedURL else { return }
                installedOllamaModels = []
                ollamaModelLookupStatus = "Lookup failed"
                alertMessage = error.localizedDescription
            }
        }
    }

    func testProvider() {
        let configuration = currentProviderConfiguration
        Task {
            do {
                let service = InferenceService(configuration: configuration)
                try await service.connectivityTest()
                providerReadiness = .connected
            } catch {
                providerReadiness = .unavailable
                alertMessage = error.localizedDescription
            }
        }
    }

    /// Runs one real search, because reaching SearXNG is not the same as it
    /// being willing to answer in JSON.
    func testSearXNG() {
        let requestedURL = searxngURL
        isTestingSearXNG = true
        searxngStatus = "Testing…"
        Task {
            defer { isTestingSearXNG = false }
            do {
                guard let url = URL(string: requestedURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    throw WebResearchError.invalidSearchEndpoint
                }
                let results = try await SearXNGClient(baseURL: url).search("ProjectOS")
                guard searxngURL == requestedURL else { return }
                searxngStatus = results.isEmpty
                    ? "Answered, but returned no results for a test search"
                    : "Connected · JSON results enabled"
            } catch {
                guard searxngURL == requestedURL else { return }
                searxngStatus = "Not reachable"
                alertMessage = error.localizedDescription
            }
        }
    }

    private func makeWebResearchToolbox(userMessage: String) throws -> WebResearchToolbox {
        guard let url = URL(string: searxngURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw WebResearchError.invalidSearchEndpoint
        }
        return WebResearchToolbox(
            searcher: try SearXNGClient(baseURL: url),
            reader: WebPageReader(),
            userMessage: userMessage
        )
    }

    private var currentProviderConfiguration: InferenceConfiguration {
        InferenceConfiguration(provider: provider, ollamaURL: ollamaURL, model: selectedModel, openRouterRoute: openRouterRoute)
    }

    private func makeFrozenContext(project: ProjectRecord) -> FrozenProjectContext {
        let selectedSources = sources.filter { contextSelection.sourceIDs.contains($0.id) }
        // A research conversation's subject is pinned, even if deselected.
        let research = linkedResearch
        let selectedArtifacts = artifacts.filter { (contextSelection.artifactIDs.contains($0.id) || $0.id == research?.id) && $0.state != .removed && $0.state != .superseded }
        let completeMessages = messages.filter { $0.completion == .complete }.suffix(contextSelection.messageCount)
        return FrozenProjectContext(projectID: project.id, projectRevision: project.revision, projectName: project.name, projectDescription: contextSelection.includeDescription ? project.summary : nil, sources: selectedSources, artifacts: selectedArtifacts, messages: Array(completeMessages), provider: provider, model: selectedModel, focusResearchID: research?.id)
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

    private func beginJob(purpose: AIJobPurpose, context: FrozenProjectContext, usesWebResearch: Bool = false) -> UUID? {
        let job = InferenceJobRecord(id: UUID(), contextID: UUID(), projectID: context.projectID, sourceRevision: context.projectRevision, provider: context.provider.rawValue, model: context.model, configuredUpstreamRoute: context.provider == .openRouter ? openRouterRoute : nil, purpose: purpose.rawValue, sourceIDs: context.sources.map(\.id), artifactIDs: context.artifacts.map(\.id), messageIDs: context.messages.map(\.id), createdAt: Date(), status: .running)
        do {
            try requireStore().saveJob(job)
            activeJobRecord = job
            upsertJob(job)
            // A next action is grounded in accepted records alone.
            let contextSummary = purpose == .nextAction
                ? GenerationActivity.contextSummary(includesDescription: false, sources: 0, records: context.artifacts.count, messages: 0)
                : GenerationActivity.contextSummary(includesDescription: context.projectDescription != nil, sources: context.sources.count, records: context.artifacts.count, messages: context.messages.count)
            activity = GenerationActivity(id: job.id, projectID: context.projectID, projectName: context.projectName, purpose: purpose, provider: context.provider, model: context.model, route: job.configuredUpstreamRoute, contextSummary: contextSummary, usesWebResearch: usesWebResearch)
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
        } catch { alertMessage = error.localizedDescription }
    }

    /// Phase reports from a provider request, applied only while that request
    /// is still the one on screen.
    private func progress(for jobID: UUID) -> AIJobProgress {
        { [weak self] phase in await self?.advanceActivity(to: phase, expectedID: jobID) }
    }

    private func advanceActivity(to phase: AIJobPhase, expectedID: UUID) {
        guard var current = activity, current.id == expectedID, current.advance(to: phase) else { return }
        activity = current
    }

    /// Names the search or page the model is on, so the sidebar says what is
    /// happening rather than only that something is.
    private func noteResearch(_ step: WebResearchStep, expectedID: UUID) {
        guard var current = activity, current.id == expectedID else { return }
        let note: String? = switch (step.action, step.status) {
        case (.search, .running): step.subject.isEmpty ? "Searching the web" : "Searching “\(step.subject)”"
        case (.read, .running): "Reading \(URL(string: step.subject)?.host ?? "a page")"
        default: nil
        }
        guard current.note(note) else { return }
        activity = current
    }

    private func finishActivity(_ outcome: GenerationActivity.Outcome, expectedID: UUID) {
        guard var current = activity, current.id == expectedID, current.finish(outcome) else { return }
        activity = current
        guard case .completed = outcome else { return }
        // A success needs no acknowledgement, so it clears once it has been seen.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, self.activity?.id == expectedID else { return }
            self.activity = nil
        }
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
