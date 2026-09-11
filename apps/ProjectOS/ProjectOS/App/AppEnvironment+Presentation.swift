import Foundation

/// Derived, read-only state for the UI.
///
/// Views ask questions in the product's own vocabulary — "what is governing?",
/// "what needs attention?" — instead of re-deriving the same filters. Keeping
/// these here means one definition per question, and views that stay about
/// layout.
extension AppEnvironment {
    // MARK: - Navigation

    /// Moves to a destination. Centralised so a navigation change can grow
    /// behaviour (restoring a filter, say) without touching every call site.
    func show(_ destination: WorkspaceDestination) {
        guard self.destination != destination else { return }
        self.destination = destination
    }

    // MARK: - Accepted state

    /// Records that still describe the project, excluding removed ones.
    var liveArtifacts: [ArtifactRecord] {
        artifacts.filter { $0.state != .removed }
    }

    /// Decisions that currently govern the project.
    var governingDecisions: [ArtifactRecord] {
        artifacts.filter { $0.kind == .decision && $0.state == .current }
    }

    var supersededDecisions: [ArtifactRecord] {
        artifacts.filter { $0.kind == .decision && $0.state == .superseded }
    }

    var openQuestions: [ArtifactRecord] {
        artifacts.filter { $0.kind == .openQuestion && $0.state == .open }
    }

    /// Tasks that are not finished, dismissed, or removed.
    var openTasks: [ArtifactRecord] {
        artifacts.filter { $0.kind == .task && ArtifactState.unfinishedTaskStates.contains($0.state) }
    }

    var researchRecords: [ArtifactRecord] {
        artifacts.filter { $0.kind == .research && $0.state != .removed }
    }

    /// The count shown beside a sidebar destination, or `nil` when a count
    /// would add noise rather than orientation.
    func badgeCount(for destination: WorkspaceDestination) -> Int? {
        let count: Int
        switch destination {
        case .overview, .settings, .changeLog:
            return nil
        case .conversation:
            count = conversations.count
        case .ledger(let kind):
            guard let kind else { return liveArtifacts.count }
            count = liveArtifacts.filter { $0.kind == kind }.count
        case .proposals:
            count = actionableProposals.count
        case .sources:
            count = sources.count
        }
        return count > 0 ? count : nil
    }

    // MARK: - Proposals

    /// Proposals still awaiting the person's explicit decision.
    var actionableProposals: [ProposalRecord] {
        proposals.filter { $0.lifecycle.isActionable }
    }

    var pendingProposals: [ProposalRecord] {
        proposals.filter { $0.lifecycle == .pending }
    }

    var reviewedProposals: [ProposalRecord] {
        proposals.filter { !$0.lifecycle.isActionable }
    }

    // MARK: - Covers

    /// The cover for a project in the library.
    func coverSpec(for project: ProjectRecord) -> PileCoverSpec {
        projectCovers[project.id] ?? PileCoverSpec()
    }

    /// The open project's cover, composed from state already in memory so it
    /// stays live while the person works.
    var activeCoverSpec: PileCoverSpec {
        PileCoverComposer.spec(artifacts: artifacts, proposals: proposals, changes: changes)
    }

    // MARK: - Provenance

    /// How many distinct sources a record cites.
    func provenanceCount(for artifact: ArtifactRecord) -> Int {
        Set(artifact.evidence.map(\.sourceID)).count
    }

    /// The accepted changes that touched a record, newest first.
    func history(for artifact: ArtifactRecord) -> [ChangeRecord] {
        changes.filter { $0.beforeArtifact?.id == artifact.id || $0.afterArtifact?.id == artifact.id }
    }

    func artifact(with id: UUID) -> ArtifactRecord? {
        artifacts.first { $0.id == id }
    }

    // MARK: - Provider disclosure

    /// The adapter and model that a provider-contacting action would use, named
    /// before anything leaves the Mac.
    var activeModelDescription: String {
        switch provider {
        case .ollama:
            let model = ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines)
            return model.isEmpty ? "Ollama · no model selected" : "Ollama · \(model)"
        case .openRouter:
            let model = openRouterModel.trimmingCharacters(in: .whitespacesAndNewlines)
            return model.isEmpty ? "OpenRouter · no model selected" : "OpenRouter · \(model)"
        }
    }

    /// Whether the configured provider runs on this Mac.
    var runsLocally: Bool { provider == .ollama }

    /// The one-line disclosure shown next to any action that would contact a
    /// provider.
    var providerDisclosure: String {
        runsLocally
            ? "Runs on this Mac with \(activeModelDescription). Project context stays local."
            : "Sends the previewed context to \(activeModelDescription). Billed separately by OpenRouter."
    }
}
