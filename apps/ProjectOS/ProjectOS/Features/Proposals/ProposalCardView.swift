import SwiftUI

/// A pending Change Proposal, with the shared inspector anatomy: proposed
/// value, effects, dependencies, provenance, status, and explicit actions.
///
/// Pending treatment must never resemble an accepted Artifact Row, so the card
/// carries a dashed boundary and a pending badge, and separation — not
/// elevation — keeps it outside Canonical State.
struct ProposalCardView: View {
    let proposal: ProposalRecord
    /// Compact form drops editing and long-form context for a narrow rail.
    var isCompact = false

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var title: String
    @State private var content: String
    @State private var confirmsDecision = false
    @State private var isExpanded = false

    init(proposal: ProposalRecord, isCompact: Bool = false) {
        self.proposal = proposal
        self.isCompact = isCompact
        _title = State(initialValue: proposal.title)
        _content = State(initialValue: proposal.content)
    }

    private var dependencies: [ProposalRecord] { environment.dependencyClosure(for: proposal) }

    /// A decision commits the project, so accepting one — directly or through a
    /// dependency — takes an explicit confirmation.
    private var requiresDecisionConfirmation: Bool {
        proposal.kind == .decision || dependencies.contains { $0.kind == .decision }
    }

    private var acceptTitle: String {
        proposal.dependencyIDs.isEmpty ? "Accept" : "Accept reviewed set"
    }

    var body: some View {
        SurfaceContainer(role: .surface, boundary: .pending, radius: Radius.md, padding: Spacing.step3) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                header
                editableFields
                context
                if isCompact && !isExpanded {
                    Button("Show details") { withAnimation(Motion.standard) { isExpanded = true } }
                        .buttonStyle(.posGhost)
                } else {
                    details
                }
                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.step2) {
            RowGlyph(systemImage: proposal.kind.symbolName, tone: proposal.kind.tone, isFilled: false)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(proposal.operation.displayName) \(proposal.kind.rawValue.lowercased())")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
                Text("Proposed \(proposal.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            }
            Spacer(minLength: Spacing.step2)
            StatusBadge(
                text: proposal.lifecycle.displayName,
                symbol: proposal.lifecycle.symbolName,
                tone: proposal.lifecycle.tone
            )
        }
    }

    private var editableFields: some View {
        VStack(alignment: .leading, spacing: Spacing.step2) {
            FormTextField(label: "Proposed title", text: $title)
            FormTextField(label: "Proposed content", text: $content, lineLimit: 2 ... 8)
        }
    }

    @ViewBuilder
    private var context: some View {
        VStack(alignment: .leading, spacing: Spacing.step1) {
            if let rationale = proposal.rationale, !rationale.isEmpty {
                DisclosureNote(text: "Why: \(rationale)", systemImage: "text.quote")
            }
            if let state = proposal.proposedState {
                DisclosureNote(text: "Proposed status: \(state.displayName)", systemImage: "flag")
            }
            if let certainty = proposal.certainty, !certainty.isEmpty {
                DisclosureNote(text: "Certainty: \(certainty)", systemImage: "gauge.medium")
            }
            if let limitations = proposal.limitations, !limitations.isEmpty {
                DisclosureNote(text: "Limitations: \(limitations)", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.step3) {
            if !dependencies.isEmpty {
                EffectPanel(title: "Accepted atomically with", tone: .warning) {
                    ForEach(dependencies) { dependency in
                        Text("• \(dependency.kind.rawValue): \(dependency.title)")
                            .font(TypeRole.caption)
                            .foregroundStyle(theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            supersessionPanel

            if !proposal.evidence.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.step1) {
                    FieldGroupLabel(text: "Provenance")
                    ForEach(proposal.evidence) { evidence in
                        EvidenceChip(evidence: evidence) { environment.inspectEvidence(evidence) }
                    }
                }
            }

            if requiresDecisionConfirmation {
                VStack(alignment: .leading, spacing: Spacing.step1) {
                    Toggle("I confirm the decision(s) in this reviewed set", isOn: $confirmsDecision)
                        .font(TypeRole.caption)
                        .toggleStyle(.checkbox)
                    DisclosureNote(
                        text: "A matching quote proves only that the text exists. Review the commitment and its rationale before accepting.",
                        systemImage: "exclamationmark.shield"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var supersessionPanel: some View {
        if proposal.operation == .supersede,
           let prior = proposal.targetID.flatMap({ environment.artifact(with: $0) }) {
            EffectPanel(title: "Replaces the current decision", tone: .warning) {
                Text(prior.title)
                    .font(TypeRole.caption.weight(.semibold))
                    .foregroundStyle(theme.text)
                Text(prior.content)
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if let prior = environment.replacementCandidate(for: proposal) {
            EffectPanel(title: "A current decision already governs this subject", tone: .warning) {
                Text(prior.title)
                    .font(TypeRole.caption.weight(.semibold))
                    .foregroundStyle(theme.text)
                Button("Mark as explicit replacement") {
                    environment.markAsReplacement(proposal, prior: prior)
                }
                .buttonStyle(.posSecondary)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.step2) {
            Button("Reject") { environment.setProposal(proposal, lifecycle: .rejected) }
                .buttonStyle(.posGhost)
            if proposal.lifecycle != .deferred {
                Button("Defer") { environment.setProposal(proposal, lifecycle: .deferred) }
                    .buttonStyle(.posGhost)
            }
            Spacer(minLength: Spacing.step2)
            Button(acceptTitle) { environment.accept(proposal, title: title, content: content) }
                .buttonStyle(.posPrimary)
                .disabled(requiresDecisionConfirmation && !confirmsDecision)
        }
    }
}

/// A bounded panel describing what accepting a proposal would affect.
struct EffectPanel<Content: View>: View {
    let title: String
    var tone: StatusBadge.Tone = .warning
    @ViewBuilder var content: Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step1) {
            HStack(spacing: Spacing.step1) {
                Image(systemName: "arrow.triangle.branch")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text(title)
                    .font(TypeRole.caption.weight(.semibold))
            }
            .foregroundStyle(tone == .warning ? theme.warning : theme.text)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.step2)
        .background(theme.tint, in: RoundedRectangle(cornerRadius: Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sm)
                .strokeBorder(theme.essentialBoundary.opacity(0.4), lineWidth: Stroke.hairline)
        }
    }
}

/// One cited excerpt. Opening it shows the exact retained source text.
struct EvidenceChip: View {
    let evidence: EvidenceRecord
    let inspect: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: inspect) {
            VStack(alignment: .leading, spacing: Spacing.step1) {
                Text("“\(evidence.quote)”")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.step1) {
                    Text("\(evidence.sourceType) · version \(evidence.version)")
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                    if evidence.aiAuthored {
                        StatusBadge(text: "AI-authored · unverified", symbol: "exclamationmark.triangle", tone: .warning)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.step2)
            .background(theme.tint, in: RoundedRectangle(cornerRadius: Radius.sm))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Inspect source for quote: \(evidence.quote)")
    }
}
