import SwiftUI

/// A relationship, inspected on its own terms.
///
/// Edges are not decoration between two records. Selecting one explains what it
/// means, which records it joins, whether it still holds, and what to do about
/// it if it does not — without opening either endpoint.
struct RelationshipInspectorView: View {
    let edge: GraphEdge
    let graph: ProjectGraph
    let focus: (UUID) -> Void
    let close: () -> Void

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    private var source: GraphNode? { graph.node(edge.sourceID) }
    private var target: GraphNode? { graph.node(edge.targetID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            DecorativeDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.step4) {
                    meaningSection
                    endpointsSection
                    if edge.state == .needsReview { reviewSection }
                    provenanceSection
                }
                .padding(Spacing.step4)
            }
        }
        .background(theme.surfaceRaised)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.step3) {
            RowGlyph(
                systemImage: "arrow.triangle.branch",
                tone: edge.state == .needsReview ? .warning : .accent,
                isFilled: false
            )
            VStack(alignment: .leading, spacing: Spacing.step1) {
                Text("Relationship")
                    .font(TypeRole.eyebrow)
                    .foregroundStyle(theme.muted)
                StatusBadge(
                    text: edge.state.displayName,
                    symbol: edge.state.symbolName,
                    tone: edge.state == .needsReview ? .warning : (edge.state == .current ? .success : .muted)
                )
            }
            Spacer(minLength: Spacing.step2)
            IconButton(systemImage: "xmark", accessibilityLabel: "Close inspector", action: close)
        }
        .padding(Spacing.step4)
    }

    private var meaningSection: some View {
        SectionCard(title: "What it means", role: .surface) {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                Text(graph.meaning(of: edge))
                    .font(TypeRole.body)
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                MetaRow(label: "Type", value: edge.type)
                MetaRow(label: "State", value: edge.state.displayName)
                if edge.state == .proposed {
                    DisclosureNote(
                        text: "This relationship belongs to a proposal. It is not part of project state until you accept it.",
                        systemImage: "sparkles"
                    )
                }
            }
        }
    }

    private var endpointsSection: some View {
        SectionCard(title: "Records it joins", role: .surface) {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                endpoint(source, role: "From")
                endpoint(target, role: "To")
            }
        }
    }

    @ViewBuilder
    private func endpoint(_ node: GraphNode?, role: String) -> some View {
        if let node {
            RecordRow(
                title: node.title,
                subtitle: role,
                action: { focus(node.id) }
            ) {
                RowGlyph(
                    systemImage: node.kind?.symbolName ?? "bubble.left.and.bubble.right",
                    tone: node.kind?.tone ?? .muted
                )
            } trailing: {
                if let state = node.state {
                    StatusMark(text: state.displayName, symbol: state.symbolName, tone: state.tone)
                }
            }
            .help("Focus the map on \(node.title)")
        } else {
            InlineEmptyText(text: "\(role): a record that is no longer in project state.")
        }
    }

    private var reviewSection: some View {
        SectionCard(title: "Why it needs review", role: .surface) {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                Text(edge.reviewReason ?? "One end of this relationship has changed.")
                    .font(TypeRole.body)
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                DisclosureNote(
                    text: "It stays part of project state until you change it. Age alone never weakens a relationship.",
                    systemImage: "exclamationmark.triangle"
                )
                Button {
                    if let source { focus(source.id) }
                } label: {
                    Label("Open the record that holds it", systemImage: "arrow.forward")
                }
                .buttonStyle(.posSecondary)
                .disabled(source == nil)
                .help("Relationships are corrected on the record they belong to.")
            }
        }
    }

    private var provenanceSection: some View {
        SectionCard(title: "Where it came from", role: .surface) {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                if let source, let record = environment.artifact(with: source.id) {
                    if record.evidence.isEmpty {
                        InlineEmptyText(text: "The record holding this relationship cites no source. It is user-authored.")
                    } else {
                        ForEach(record.evidence) { evidence in
                            EvidenceChip(evidence: evidence) { environment.inspectEvidence(evidence) }
                        }
                    }
                } else {
                    InlineEmptyText(text: "No provenance available for this relationship.")
                }
            }
        }
    }
}
