import SwiftUI

/// The persistent review region beside a conversation.
///
/// It stays visually separate from the transcript and from Canonical State, so
/// a proposal can never read as accepted project truth.
struct ProposalRailView: View {
    var onClose: (() -> Void)?

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step3) {
            header
            Button {
                environment.suggestUpdates()
            } label: {
                Label("Suggest project updates", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.posPrimary)
            .disabled(environment.isGenerating)

            DisclosureNote(
                text: environment.providerDisclosure,
                systemImage: environment.runsLocally ? "desktopcomputer" : "network"
            )

            DecorativeDivider()

            if environment.actionableProposals.isEmpty {
                EmptyStateView(
                    title: "No pending updates",
                    message: "Request suggestions from the context you have disclosed below.",
                    systemImage: "tray"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.step3) {
                        ForEach(environment.actionableProposals) { proposal in
                            ProposalCardView(proposal: proposal, isCompact: true)
                        }
                    }
                    .padding(.bottom, Spacing.step3)
                }
            }
        }
        .padding(Spacing.step3)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.sidebar)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Project Updates")
                    .font(TypeRole.heading)
                    .foregroundStyle(theme.text)
                    .accessibilityIdentifier("conversation.project-updates-heading")
                Text("Pending — never automatic truth")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            }
            Spacer(minLength: Spacing.step2)
            if let onClose {
                IconButton(systemImage: "xmark", accessibilityLabel: "Close Project Updates", action: onClose)
            }
        }
    }
}

/// The full-width proposal review destination: everything awaiting a decision,
/// then the proposals already reviewed.
struct ProposalsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            SurfaceHeader(eyebrow: "Change Proposals", title: "Proposals") {
                Text("Proposals become project state only when you accept them.")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            } actions: {
                Button {
                    environment.suggestUpdates()
                } label: {
                    Label("Suggest project updates", systemImage: "sparkles")
                }
                .buttonStyle(.posPrimary)
                .disabled(environment.isGenerating)
            }
            DecorativeDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.step5) {
                    if environment.actionableProposals.isEmpty {
                        EmptyStateView(
                            title: "Nothing awaiting review",
                            message: "Continue a conversation and ask for project updates when you want the agent to propose changes.",
                            systemImage: "tray",
                            primary: .init(title: "Open conversation") { environment.show(.conversation) }
                        )
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.step3) {
                            FieldGroupLabel(text: "Awaiting your decision")
                            ForEach(environment.actionableProposals) { proposal in
                                ProposalCardView(proposal: proposal)
                            }
                        }
                    }

                    if !environment.reviewedProposals.isEmpty {
                        SectionCard(title: "Already reviewed") {
                            RowList(items: environment.reviewedProposals) { proposal in
                                RecordRow(
                                    title: proposal.title,
                                    subtitle: "\(proposal.operation.displayName) \(proposal.kind.rawValue.lowercased())"
                                ) {
                                    RowGlyph(
                                        systemImage: proposal.lifecycle.symbolName,
                                        tone: proposal.lifecycle.tone,
                                        isFilled: false
                                    )
                                } trailing: {
                                    StatusBadge(text: proposal.lifecycle.displayName, tone: .muted)
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.step5)
                .frame(maxWidth: Spacing.readableWidth, alignment: .leading)
            }
        }
        .background(theme.canvas)
        .navigationTitle("Proposals")
    }
}
