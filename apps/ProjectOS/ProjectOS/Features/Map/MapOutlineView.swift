import SwiftUI

/// The map without the canvas.
///
/// This is not a lesser fallback: it carries the same records, the same
/// relationships, the same selection, and the same actions, in a stable
/// type-and-title order. Anyone who would rather read a list than navigate a
/// plane — including anyone using a screen reader — gets the whole surface.
struct MapOutlineView: View {
    let graph: ProjectGraph
    @Binding var selection: MapSelection?
    @Binding var focusID: UUID?

    @Environment(\.theme) private var theme
    @State private var expanded: Set<UUID> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.step2) {
                ForEach(graph.ordered) { node in
                    VStack(alignment: .leading, spacing: Spacing.step2) {
                        row(for: node)
                        if expanded.contains(node.id) {
                            relationships(for: node)
                                .padding(.leading, Spacing.step5)
                        }
                    }
                }
            }
            .padding(Spacing.step5)
        }
        .accessibilityLabel("Project map outline")
    }

    private func row(for node: GraphNode) -> some View {
        let isExpanded = expanded.contains(node.id)
        let incoming = graph.incoming(node.id).count
        let outgoing = graph.outgoing(node.id).count

        return SurfaceContainer(
            role: .surface,
            boundary: selection == .node(node.id) ? .selected : (node.role == .proposed ? .pending : .essential),
            padding: Spacing.step1
        ) {
            RecordRow(
                title: node.title,
                subtitle: node.detail.isEmpty ? nil : node.detail,
                isSelected: selection == .node(node.id),
                action: { selection = .node(node.id) }
            ) {
                RowGlyph(
                    systemImage: node.kind?.symbolName ?? "bubble.left.and.bubble.right",
                    tone: node.isHistorical ? .muted : (node.kind?.tone ?? .muted)
                )
            } trailing: {
                HStack(spacing: Spacing.step3) {
                    if let state = node.state {
                        StatusMark(text: state.displayName, symbol: state.symbolName, tone: state.tone)
                    }
                    if node.role == .proposed {
                        StatusBadge(text: "Proposed", symbol: "sparkles", tone: .accent)
                    }
                    Button {
                        if isExpanded { expanded.remove(node.id) } else { expanded.insert(node.id) }
                    } label: {
                        HStack(spacing: Spacing.step1) {
                            Text("\(incoming + outgoing)")
                                .font(TypeRole.caption)
                                .monospacedDigit()
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .imageScale(.small)
                        }
                        .foregroundStyle(theme.muted)
                        .frame(minWidth: 24, minHeight: 24)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        isExpanded
                            ? "Collapse relationships for \(node.title)"
                            : "Expand \(incoming + outgoing) relationships for \(node.title)"
                    )
                }
            }
        }
        .opacity(node.isHistorical ? 0.75 : 1)
    }

    @ViewBuilder
    private func relationships(for node: GraphNode) -> some View {
        let incoming = graph.incoming(node.id)
        let outgoing = graph.outgoing(node.id)

        VStack(alignment: .leading, spacing: Spacing.step3) {
            if incoming.isEmpty && outgoing.isEmpty {
                InlineEmptyText(text: "Not linked to another record.")
            }
            if !outgoing.isEmpty {
                group(title: "Outgoing", edges: outgoing, from: node, isOutgoing: true)
            }
            if !incoming.isEmpty {
                group(title: "Incoming", edges: incoming, from: node, isOutgoing: false)
            }
            HStack(spacing: Spacing.step2) {
                if focusID == node.id {
                    Button("Show whole map") { focusID = nil }
                        .buttonStyle(.posGhost)
                } else {
                    Button {
                        focusID = node.id
                    } label: {
                        Label("Focus", systemImage: "scope")
                    }
                    .buttonStyle(.posGhost)
                }
            }
        }
    }

    private func group(title: String, edges: [GraphEdge], from node: GraphNode, isOutgoing: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.step1) {
            FieldGroupLabel(text: title)
            ForEach(edges) { edge in
                let otherID = isOutgoing ? edge.targetID : edge.sourceID
                let other = graph.node(otherID)
                RecordRow(
                    title: other?.title ?? "Record no longer in project state",
                    subtitle: isOutgoing
                        ? "\(node.title) \(edge.type) this"
                        : "this \(edge.type) \(node.title)",
                    isSelected: selection == .relationship(edge.id),
                    action: { selection = .relationship(edge.id) }
                ) {
                    RowGlyph(
                        systemImage: isOutgoing ? "arrow.forward" : "arrow.backward",
                        tone: edge.state == .needsReview ? .warning : .muted,
                        isFilled: false
                    )
                } trailing: {
                    StatusMark(
                        text: edge.state.displayName,
                        symbol: edge.state.symbolName,
                        tone: edge.state == .needsReview ? .warning : .muted
                    )
                }
                .accessibilityLabel(
                    "\(title) relationship. \(graph.meaning(of: edge)) \(edge.state.displayName)."
                )
            }
        }
    }
}
