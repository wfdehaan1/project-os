import Foundation

/// Everything the Overview surface shows, computed once from project state.
///
/// The view renders this and nothing else. Keeping the derivation here makes
/// the re-entry logic — how long you were away, whether a recommendation still
/// applies — testable without a view, and keeps the view about layout.
struct OverviewBriefing {
    /// The state of the generated recommendation pair.
    enum NextActionState: Equatable {
        /// A recommendation exists and still matches accepted state.
        case current(RecommendationRecord)
        /// Canonical State moved on. No stale recommendation is shown.
        case needsRecap
        /// Nothing has been generated yet.
        case none
    }

    let returnLine: String
    let projectName: String
    let projectDescription: String
    let cover: PileCoverSpec
    let nextAction: NextActionState
    let governingDecisions: [ArtifactRecord]
    let openQuestions: [ArtifactRecord]
    let openTasks: [ArtifactRecord]
    let changesSinceLastVisit: [ChangeRecord]
    let actionableProposalCount: Int

    var hasAcceptedKnowledge: Bool {
        !governingDecisions.isEmpty || !openQuestions.isEmpty || !openTasks.isEmpty
    }
}

/// Builds the Overview briefing. Pure, local, and offline: it reads accepted
/// state only and never contacts a provider.
enum OverviewBriefingBuilder {
    static func build(
        project: ProjectRecord,
        artifacts: [ArtifactRecord],
        changes: [ChangeRecord],
        changesSinceLastVisit: [ChangeRecord],
        proposals: [ProposalRecord],
        recommendation: RecommendationRecord?,
        outcomes: [ReturnRecord],
        messages: [MessageRecord],
        now: Date = Date()
    ) -> OverviewBriefing {
        let actionable = proposals.filter { $0.lifecycle.isActionable }

        return OverviewBriefing(
            returnLine: returnLine(
                project: project,
                changes: changes,
                outcomes: outcomes,
                messages: messages,
                now: now
            ),
            projectName: project.name,
            projectDescription: project.summary,
            cover: PileCoverComposer.spec(artifacts: artifacts, proposals: proposals, changes: changes),
            nextAction: nextActionState(recommendation: recommendation, project: project),
            governingDecisions: artifacts.filter { $0.kind == .decision && $0.state == .current },
            openQuestions: artifacts.filter { $0.kind == .openQuestion && $0.state == .open },
            openTasks: artifacts.filter {
                $0.kind == .task && ArtifactState.unfinishedTaskStates.contains($0.state)
            },
            changesSinceLastVisit: changesSinceLastVisit,
            actionableProposalCount: actionable.count
        )
    }

    /// A recommendation is bound to the revision it was generated from. When
    /// accepted state has moved on, the pair is invalidated rather than shown
    /// with a caveat.
    private static func nextActionState(
        recommendation: RecommendationRecord?,
        project: ProjectRecord
    ) -> OverviewBriefing.NextActionState {
        guard let recommendation, !recommendation.isDismissed else { return .none }
        return recommendation.originatingRevision == project.revision
            ? .current(recommendation)
            : .needsRecap
    }

    /// How long the person has been away, measured from the newest thing that
    /// actually happened in the project.
    private static func returnLine(
        project: ProjectRecord,
        changes: [ChangeRecord],
        outcomes: [ReturnRecord],
        messages: [MessageRecord],
        now: Date
    ) -> String {
        let candidates = [
            changes.first?.createdAt,
            outcomes.map(\.createdAt).max(),
            messages.last?.createdAt,
        ].compactMap { $0 }

        guard let last = candidates.max() else { return "New project" }

        let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
        switch days {
        case ..<1: return "Continuing today"
        case 1: return "Back after a day"
        default: return "Back after \(days) days"
        }
    }
}
