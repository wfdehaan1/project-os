import SwiftUI

/// The re-entry surface: where am I, and what matters now?
///
/// Opening Overview is entirely local. Nothing here contacts a provider until
/// the person asks for a recommendation.
struct OverviewView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    private var briefing: OverviewBriefing? {
        guard let project = environment.selectedProject else { return nil }
        return OverviewBriefingBuilder.build(
            project: project,
            artifacts: environment.artifacts,
            changes: environment.changes,
            changesSinceLastVisit: environment.changesSincePreviousVisit,
            proposals: environment.proposals,
            recommendation: environment.recommendation,
            outcomes: environment.outcomes,
            messages: environment.messages
        )
    }

    var body: some View {
        ScrollView {
            if let briefing {
                VStack(alignment: .leading, spacing: Spacing.step5) {
                    masthead(briefing)
                    mastheadRow(briefing)
                    if !briefing.projectDescription.isEmpty {
                        SectionCard(title: "What this project is") {
                            Text(briefing.projectDescription)
                                .font(TypeRole.body)
                                .foregroundStyle(theme.text)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if briefing.hasAcceptedKnowledge {
                        stateRow(briefing)
                    } else {
                        emptyKnowledge
                    }
                    sinceLastVisit(briefing)
                }
                .padding(Spacing.step5)
                .frame(maxWidth: Spacing.readableWidth, alignment: .leading)
            }
        }
        .background(theme.canvas)
        .navigationTitle("Overview")
    }

    // MARK: - Masthead

    private func masthead(_ briefing: OverviewBriefing) -> some View {
        HStack(alignment: .top, spacing: Spacing.step4) {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                Text(briefing.returnLine)
                    .font(TypeRole.label)
                    .foregroundStyle(theme.muted)
                Text(briefing.projectName)
                    .font(TypeRole.title)
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                LocalStorageStatus(detail: "Revision \(environment.selectedProject?.revision ?? 0)")
            }
            Spacer(minLength: Spacing.step3)
            VStack(alignment: .trailing, spacing: Spacing.step2) {
                if briefing.actionableProposalCount > 0 {
                    Button {
                        environment.show(.proposals)
                    } label: {
                        Label(
                            "\(briefing.actionableProposalCount) \(briefing.actionableProposalCount == 1 ? "proposal" : "proposals") to review",
                            systemImage: "tray.full"
                        )
                    }
                    .buttonStyle(.posSecondary)
                }
                Button("Record return outcome") { environment.showOutcome = true }
                    .buttonStyle(.posGhost)
            }
        }
    }

    /// Pile Cover and What's Up Next share one content-driven row, and stack
    /// when the width or the text size needs them to.
    private func mastheadRow(_ briefing: OverviewBriefing) -> some View {
        AdaptiveColumns(minimumColumnWidth: 300, leadingWidth: 300) {
            PileCoverPanel(spec: briefing.cover)
            NextActionCard(state: briefing.nextAction)
        }
    }

    // MARK: - Accepted state

    private func stateRow(_ briefing: OverviewBriefing) -> some View {
        AdaptiveColumns(minimumColumnWidth: 320) {
            currentTruth(briefing)
            needsAttention(briefing)
        }
    }

    private func currentTruth(_ briefing: OverviewBriefing) -> some View {
        SectionCard(title: "Current truth") {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                FieldGroupLabel(text: "Governing")
                if briefing.governingDecisions.isEmpty {
                    InlineEmptyText(text: "No governing decisions yet.")
                } else {
                    RowList(items: Array(briefing.governingDecisions.prefix(4))) { decision in
                        RecordRow(
                            title: decision.title,
                            subtitle: decision.content,
                            showsDisclosure: true,
                            action: { environment.show(.ledger(.decision)) }
                        ) {
                            RowGlyph(systemImage: "checkmark.seal.fill", tone: .accent)
                        }
                    }
                }
                CardFooterLink(title: "View all decisions") { environment.show(.ledger(.decision)) }
            }
        }
    }

    private func needsAttention(_ briefing: OverviewBriefing) -> some View {
        SectionCard(title: "Needs attention") {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                VStack(alignment: .leading, spacing: Spacing.step2) {
                    FieldGroupLabel(text: "Open questions")
                    if briefing.openQuestions.isEmpty {
                        InlineEmptyText(text: "Nothing unresolved.")
                    } else {
                        RowList(items: Array(briefing.openQuestions.prefix(3))) { question in
                            RecordRow(
                                title: question.title,
                                showsDisclosure: true,
                                action: { environment.show(.ledger(.openQuestion)) }
                            ) {
                                RowGlyph(systemImage: "questionmark", tone: .warning, isFilled: false)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.step2) {
                    FieldGroupLabel(text: "Tasks")
                    if briefing.openTasks.isEmpty {
                        InlineEmptyText(text: "No open work.")
                    } else {
                        RowList(items: Array(briefing.openTasks.prefix(4))) { task in
                            RecordRow(
                                title: task.title,
                                showsDisclosure: true,
                                action: { environment.show(.ledger(.task)) }
                            ) {
                                RowGlyph(systemImage: task.state.symbolName, tone: task.state.tone, isFilled: false)
                            } trailing: {
                                StatusBadge(text: task.state.displayName, tone: .muted)
                            }
                        }
                    }
                }
                CardFooterLink(title: "View all tasks") { environment.show(.ledger(.task)) }
            }
        }
    }

    private var emptyKnowledge: some View {
        SurfaceContainer {
            EmptyStateView(
                title: "No accepted project knowledge yet",
                message: "Paste material, converse, and explicitly accept useful project updates. Overview stays available offline.",
                systemImage: "checkmark.seal",
                primary: .init(title: "Start a conversation") { environment.show(.conversation) },
                secondary: .init(title: "Paste source material") { environment.showAddSource = true }
            )
        }
    }

    // MARK: - History

    private func sinceLastVisit(_ briefing: OverviewBriefing) -> some View {
        SectionCard(title: "Since your last visit") {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                if briefing.changesSinceLastVisit.isEmpty {
                    InlineEmptyText(text: "No accepted changes since the previous visit.")
                } else {
                    RowList(items: Array(briefing.changesSinceLastVisit.prefix(6))) { change in
                        RecordRow(title: change.summary) {
                            RowGlyph(systemImage: "checkmark", tone: .success)
                        } trailing: {
                            Text(change.createdAt, style: .relative)
                                .font(TypeRole.caption)
                                .foregroundStyle(theme.muted)
                        }
                    }
                }
                CardFooterLink(title: "View all changes") { environment.show(.changeLog) }
            }
        } accessory: {
            Button("Undo latest") { environment.undoLatest() }
                .buttonStyle(.posGhost)
                .disabled(environment.changes.isEmpty)
        }
    }
}

/// What's Up Next: the generated continuation pair, its status, and the
/// provider disclosure that applies before anything is generated.
private struct NextActionCard: View {
    let state: OverviewBriefing.NextActionState

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceContainer(padding: Spacing.step4) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                HStack {
                    Text("What's up next")
                        .font(TypeRole.heading)
                        .foregroundStyle(theme.text)
                    Spacer(minLength: Spacing.step2)
                    badge
                }
                body(for: state)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: Spacing.mastheadMinimumHeight)
    }

    @ViewBuilder
    private var badge: some View {
        switch state {
        case .current:
            StatusBadge(text: "Current", symbol: "checkmark.circle.fill", tone: .success)
        case .needsRecap:
            StatusBadge(text: "Needs recap", symbol: "arrow.clockwise", tone: .warning)
        case .none:
            StatusBadge(text: "Not generated", symbol: "circle.dashed", tone: .muted)
        }
    }

    @ViewBuilder
    private func body(for state: OverviewBriefing.NextActionState) -> some View {
        switch state {
        case .current(let recommendation):
            VStack(alignment: .leading, spacing: Spacing.step3) {
                Text(recommendation.text)
                    .font(TypeRole.body.weight(.medium))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let uncertainty = recommendation.uncertainty, !uncertainty.isEmpty {
                    DisclosureNote(text: "Uncertainty: \(uncertainty)", systemImage: "questionmark.circle")
                }
                ForEach(recommendation.supportingRecords) { support in
                    if let artifact = environment.artifact(with: support.id) {
                        DisclosureNote(
                            text: "Grounded in \(artifact.kind.rawValue.lowercased()): \(artifact.title) · v\(support.version)",
                            systemImage: "link"
                        )
                    }
                }
                HStack(spacing: Spacing.step2) {
                    Button("Continue work") { environment.show(.conversation) }
                        .buttonStyle(.posPrimary)
                    Button("Dismiss") { environment.dismissRecommendation() }
                        .buttonStyle(.posGhost)
                }
            }

        case .needsRecap:
            VStack(alignment: .leading, spacing: Spacing.step3) {
                Text("Accepted project state changed. No stale recommendation is shown.")
                    .font(TypeRole.body)
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                generateButton(title: "Generate recap")
            }

        case .none:
            VStack(alignment: .leading, spacing: Spacing.step3) {
                Text("Optional guidance is generated only when you ask, and must cite accepted records. Opening Overview never sends project data.")
                    .font(TypeRole.body)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                generateButton(title: "Suggest next action")
            }
        }
    }

    private func generateButton(title: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.step2) {
            Button {
                environment.suggestNextAction()
            } label: {
                Label(title, systemImage: "sparkles")
            }
            .buttonStyle(.posPrimary)
            .disabled(environment.isGenerating || environment.artifacts.isEmpty)

            DisclosureNote(
                text: environment.artifacts.isEmpty
                    ? "Unavailable until the project has accepted records to cite."
                    : environment.providerDisclosure,
                systemImage: environment.runsLocally ? "desktopcomputer" : "network"
            )
        }
    }
}
