import AppKit
import SwiftUI

/// The Project Map: accepted records and the typed relationships between them.
///
/// Overview answers "where am I, and what matters now?". This surface answers
/// "how is what the project knows connected, and where can I intervene?".
/// Everything here is local — selecting, filtering, focusing, and inspecting
/// never contact a provider.
struct ProjectMapView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lens: MapLens = .currentState
    @State private var showsHistorical = false
    @State private var showsProposed = false
    @State private var selection: MapSelection?
    @State private var focusID: UUID?
    @State private var zoom: CGFloat = 1
    @State private var showsOutline = false

    private var graph: ProjectGraph {
        ProjectGraphBuilder.build(
            artifacts: environment.artifacts,
            conversations: environment.conversations,
            proposals: environment.proposals,
            retainedSourceIDs: Set(environment.sources.map(\.id)),
            lens: lens,
            showsHistorical: showsHistorical,
            showsProposed: showsProposed,
            focusID: focusID
        )
    }

    private var selectedArtifact: ArtifactRecord? {
        guard case .node(let id) = selection else { return nil }
        return environment.artifact(with: id)
    }

    private var selectedEdge: GraphEdge? {
        guard case .relationship(let id) = selection else { return nil }
        return graph.edge(id)
    }

    var body: some View {
        HSplitView {
            map.frame(minWidth: 420)
            inspectorPane.frame(minWidth: 320, idealWidth: 380)
        }
        .background(theme.canvas)
        .navigationTitle("Project Map")
    }

    // MARK: - Map

    private var map: some View {
        VStack(spacing: 0) {
            header
            controls
            DecorativeDivider()
            content
        }
    }

    private var header: some View {
        SurfaceHeader(eyebrow: "Project knowledge", title: "Project Map") {
            LocalStorageStatus(detail: summary)
        } actions: {
            Button {
                withAnimation(Motion.respectingReduceMotion(Motion.standard, reduceMotion: reduceMotion)) {
                    showsOutline.toggle()
                }
            } label: {
                Label(
                    showsOutline ? "Show map" : "Show outline",
                    systemImage: showsOutline ? "point.topleft.down.to.point.bottomright.curvepath" : "list.bullet.indent"
                )
            }
            .buttonStyle(.posSecondary)
            .help("The outline lists the same records and relationships without needing the canvas.")
        }
    }

    private var summary: String {
        let records = graph.nodes.count == 1 ? "1 record" : "\(graph.nodes.count) records"
        let links = graph.edges.count == 1 ? "1 relationship" : "\(graph.edges.count) relationships"
        let review = graph.needsReviewCount
        return review > 0 ? "\(records) · \(links) · \(review) to review" : "\(records) · \(links)"
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Spacing.step2) {
            HStack(spacing: Spacing.step3) {
                SegmentedFilterBar(
                    items: MapLens.allCases,
                    title: \.title,
                    selection: $lens
                )
                Spacer(minLength: Spacing.step2)
                if !showsOutline { zoomControls }
            }

            HStack(spacing: Spacing.step2) {
                Text(lens.explanation)
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
                Spacer(minLength: Spacing.step2)
                LayerToggle(
                    title: "Historical",
                    symbol: "clock.arrow.circlepath",
                    isOn: $showsHistorical,
                    isLocked: lens.forcesHistorical,
                    lockedHelp: "Decision history always shows past state."
                )
                LayerToggle(
                    title: "Proposed",
                    symbol: "sparkles",
                    isOn: $showsProposed,
                    isLocked: false,
                    lockedHelp: nil
                )
            }

            if let focusID, let node = graph.node(focusID) ?? environment.artifact(with: focusID).map(node(from:)) {
                focusBanner(node)
            }
        }
        .padding(.horizontal, Spacing.step5)
        .padding(.bottom, Spacing.step3)
    }

    private func node(from artifact: ArtifactRecord) -> GraphNode {
        GraphNode(
            id: artifact.id,
            role: .accepted,
            kind: artifact.kind,
            title: artifact.title,
            detail: artifact.content,
            state: artifact.state
        )
    }

    private func focusBanner(_ node: GraphNode) -> some View {
        HStack(spacing: Spacing.step2) {
            Image(systemName: "scope")
                .imageScale(.small)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text("Focused on \(node.title) and what it connects to directly.")
                .font(TypeRole.caption)
                .foregroundStyle(theme.text)
            Spacer(minLength: Spacing.step2)
            Button("Show whole map") {
                focusID = nil
            }
            .buttonStyle(.posGhost)
        }
        .padding(.horizontal, Spacing.step3)
        .padding(.vertical, Spacing.step2)
        .background(theme.tint, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private var zoomControls: some View {
        HStack(spacing: Spacing.step1) {
            IconButton(systemImage: "minus.magnifyingglass", accessibilityLabel: "Zoom out") {
                zoom = max(0.5, zoom - 0.1)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Fit") { zoom = 1 }
                .buttonStyle(.posGhost)
                .keyboardShortcut("0", modifiers: .command)
                .help("Reset the map to its normal size")

            IconButton(systemImage: "plus.magnifyingglass", accessibilityLabel: "Zoom in") {
                zoom = min(2, zoom + 0.1)
            }
            .keyboardShortcut("+", modifiers: .command)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map zoom")
        .accessibilityValue("\(Int(zoom * 100)) percent")
    }

    @ViewBuilder
    private var content: some View {
        if graph.isEmpty {
            emptyState
        } else if showsOutline {
            MapOutlineView(graph: graph, selection: $selection, focusID: $focusID)
        } else {
            canvas
        }
    }

    private var canvas: some View {
        let layout = GraphLayout.layout(graph)
        return ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                MapEdgeLayer(graph: graph, layout: layout)
                ForEach(graph.edges) { edge in
                    if let source = layout.frame(of: edge.sourceID), let target = layout.frame(of: edge.targetID) {
                        let connection = GraphConnection(from: source, to: target)
                        RelationshipLabel(
                            edge: edge,
                            isSelected: selection == .relationship(edge.id)
                        ) {
                            selection = .relationship(edge.id)
                        }
                        .position(connection.midpoint)
                    }
                }
                ForEach(graph.nodes) { node in
                    if let origin = layout.positions[node.id] {
                        MapNodeView(
                            node: node,
                            isSelected: selection == .node(node.id),
                            isFocus: focusID == node.id,
                            needsReview: graph.outgoing(node.id).contains { $0.state == .needsReview }
                        ) {
                            selection = .node(node.id)
                        }
                        .frame(width: GraphLayout.nodeSize.width, height: GraphLayout.nodeSize.height)
                        .offset(x: origin.x, y: origin.y)
                    }
                }
            }
            .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
            .scaleEffect(zoom, anchor: .topLeading)
            .frame(
                width: layout.size.width * zoom,
                height: layout.size.height * zoom,
                alignment: .topLeading
            )
            .padding(Spacing.step4)
        }
        .accessibilityLabel("Project map canvas. The outline lists the same content.")
    }

    @ViewBuilder
    private var emptyState: some View {
        if environment.liveArtifacts.isEmpty {
            EmptyStateView(
                title: "Nothing to map yet",
                message: "The map draws accepted records and the relationships between them. Accept a change proposal, or write a record yourself, and it appears here.",
                systemImage: "point.3.connected.trianglepath.dotted",
                primary: .init(title: "Review proposals") { environment.show(.proposals) },
                secondary: .init(title: "Open the ledger") { environment.show(.ledger(nil)) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyStateView(
                title: "Nothing in this lens",
                message: "\(lens.title) matches no records right now. Another lens, or the historical layer, may have what you are looking for.",
                systemImage: "line.3.horizontal.decrease.circle",
                primary: .init(title: "Show current state") {
                    lens = .currentState
                    focusID = nil
                },
                secondary: showsHistorical ? nil : .init(title: "Add historical layer") { showsHistorical = true }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorPane: some View {
        if let selectedEdge {
            RelationshipInspectorView(
                edge: selectedEdge,
                graph: graph,
                focus: { focusID = $0; selection = .node($0) },
                close: { selection = nil }
            )
            .id(selectedEdge.id)
        } else if let selectedArtifact {
            VStack(spacing: 0) {
                ArtifactInspectorView(artifact: selectedArtifact) { selection = nil }
                DecorativeDivider()
                focusFooter(selectedArtifact.id)
            }
            .id(selectedArtifact.id)
        } else if case .node(let id) = selection, let proposal = environment.proposals.first(where: { $0.id == id }) {
            proposalPane(proposal)
        } else {
            placeholderPane
        }
    }

    private func focusFooter(_ id: UUID) -> some View {
        HStack(spacing: Spacing.step2) {
            if focusID == id {
                Button("Show whole map") { focusID = nil }
                    .buttonStyle(.posSecondary)
            } else {
                Button {
                    focusID = id
                } label: {
                    Label("Focus on this record", systemImage: "scope")
                }
                .buttonStyle(.posSecondary)
                .help("Show this record and what it connects to directly.")
            }
            Spacer(minLength: Spacing.step2)
        }
        .padding(Spacing.step4)
        .background(theme.surfaceRaised)
    }

    private func proposalPane(_ proposal: ProposalRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SurfaceHeader(eyebrow: "Not project state", title: "Proposed record", status: {
                Text("Review it before it becomes part of the project.")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            })
            DecorativeDivider()
            ScrollView {
                ProposalCardView(proposal: proposal)
                    .padding(Spacing.step3)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.sidebar)
    }

    private var placeholderPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            SurfaceHeader(title: "Nothing selected", status: {
                Text("Selecting is local. Nothing is sent anywhere.")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            })
            DecorativeDivider()
            EmptyStateView(
                title: "Select a record or a relationship",
                message: "A record shows its content, rationale, provenance, and history. A relationship explains what it means, where it came from, and whether it still holds.",
                systemImage: "sidebar.right"
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.sidebar)
    }
}

/// An explicit layer over the current map, switched on deliberately.
private struct LayerToggle: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool
    let isLocked: Bool
    let lockedHelp: String?

    @Environment(\.theme) private var theme

    private var active: Bool { isOn || isLocked }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: Spacing.step1) {
                Image(systemName: active ? "checkmark.square.fill" : "square")
                    .imageScale(.small)
                Image(systemName: symbol)
                    .imageScale(.small)
                Text(title)
            }
            .font(TypeRole.caption)
            .foregroundStyle(active ? theme.accent : theme.muted)
            .padding(.horizontal, Spacing.step2)
            .padding(.vertical, Spacing.step1 + 1)
            .frame(minHeight: 24)
            .background(active ? theme.selection : .clear, in: RoundedRectangle(cornerRadius: Radius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .strokeBorder(
                        active ? theme.selectedBoundary : theme.essentialBoundary.opacity(0.45),
                        lineWidth: Stroke.hairline
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .help(isLocked ? (lockedHelp ?? title) : "Show the \(title.lowercased()) layer")
        .accessibilityLabel("\(title) layer")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

/// Every relationship, drawn once. The lines carry no information the label and
/// the outline do not also carry, so they stay out of the accessibility tree.
private struct MapEdgeLayer: View {
    let graph: ProjectGraph
    let layout: GraphLayout.Result

    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { context, _ in
            for edge in graph.edges {
                guard let source = layout.frame(of: edge.sourceID),
                      let target = layout.frame(of: edge.targetID) else { continue }
                let connection = GraphConnection(from: source, to: target)

                var path = Path()
                path.move(to: connection.start)
                path.addCurve(to: connection.end, control1: connection.control1, control2: connection.control2)

                context.stroke(
                    path,
                    with: .color(colour(for: edge.state)),
                    style: StrokeStyle(
                        lineWidth: edge.state == .current ? 1.4 : 1.2,
                        lineCap: .round,
                        dash: dash(for: edge.state)
                    )
                )
                context.fill(arrowhead(at: connection), with: .color(colour(for: edge.state)))
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .accessibilityHidden(true)
    }

    /// Line style, not colour, separates the relationship states.
    private func dash(for state: RelationshipState) -> [CGFloat] {
        switch state {
        case .current: []
        case .needsReview: [6, 3, 2, 3]
        case .historical: [2, 4]
        case .proposed: [5, 4]
        }
    }

    private func colour(for state: RelationshipState) -> Color {
        switch state {
        case .current: theme.graphEdge
        case .needsReview: theme.warning
        case .historical: theme.muted.opacity(0.6)
        case .proposed: theme.accent.opacity(0.75)
        }
    }

    private func arrowhead(at connection: GraphConnection) -> Path {
        let size: CGFloat = 7
        let tip = connection.end
        let left = CGPoint(
            x: tip.x - size * cos(connection.angle - .pi / 7),
            y: tip.y - size * sin(connection.angle - .pi / 7)
        )
        let right = CGPoint(
            x: tip.x - size * cos(connection.angle + .pi / 7),
            y: tip.y - size * sin(connection.angle + .pi / 7)
        )
        var path = Path()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }
}

/// One record on the canvas.
private struct MapNodeView: View {
    let node: GraphNode
    let isSelected: Bool
    let isFocus: Bool
    let needsReview: Bool
    let select: () -> Void

    @Environment(\.theme) private var theme

    private var boundary: SurfaceBoundary {
        if isSelected { return .selected }
        return node.role == .proposed ? .pending : .essential
    }

    var body: some View {
        Button(action: select) {
            SurfaceContainer(
                role: node.role == .provenance ? .tint : .surface,
                boundary: boundary,
                radius: Radius.lg,
                padding: Spacing.step3
            ) {
                VStack(alignment: .leading, spacing: Spacing.step1) {
                    HStack(spacing: Spacing.step2) {
                        Image(systemName: symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(glyphColour)
                        Text(eyebrow.uppercased())
                            .font(TypeRole.eyebrow)
                            .foregroundStyle(theme.muted)
                        Spacer(minLength: 0)
                        if needsReview {
                            Image(systemName: "exclamationmark.triangle")
                                .imageScale(.small)
                                .foregroundStyle(theme.warning)
                                .accessibilityHidden(true)
                        }
                        if isFocus {
                            Image(systemName: "scope")
                                .imageScale(.small)
                                .foregroundStyle(theme.accent)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(node.title)
                        .font(TypeRole.label.weight(.semibold))
                        .foregroundStyle(theme.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if let state = node.state {
                        StatusMark(text: state.displayName, symbol: state.symbolName, tone: state.tone)
                    } else {
                        StatusMark(text: "Provenance", symbol: "bubble.left.and.bubble.right", tone: .muted)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            // Past state stays legible but never competes with what governs now.
            .opacity(node.isHistorical ? 0.72 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(node.detail.isEmpty ? node.title : node.detail)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("map.node.\(node.id.uuidString)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var eyebrow: String { node.kind?.rawValue ?? "Conversation" }

    private var symbol: String { node.kind?.symbolName ?? "bubble.left.and.bubble.right" }

    private var glyphColour: Color {
        switch node.role {
        case .proposed: theme.accent
        case .provenance: theme.muted
        case .accepted: node.isHistorical ? theme.muted : theme.accent
        }
    }

    private var accessibilityLabel: String {
        var parts = [eyebrow, node.title]
        if node.role == .proposed {
            parts.append("Proposed, not project state")
        } else if let state = node.state {
            parts.append(state.displayName)
        }
        if needsReview { parts.append("Has a relationship that needs review") }
        return parts.joined(separator: ". ")
    }
}

/// A relationship's label is also its target. Making the label the thing you
/// click keeps edges reachable by pointer and keyboard without asking anyone to
/// hit a curve.
private struct RelationshipLabel: View {
    let edge: GraphEdge
    let isSelected: Bool
    let select: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: select) {
            HStack(spacing: Spacing.step1) {
                if edge.state != .current {
                    Image(systemName: edge.state.symbolName)
                        .imageScale(.small)
                        .foregroundStyle(edge.state == .needsReview ? theme.warning : theme.muted)
                }
                Text(edge.type)
                    .font(TypeRole.caption)
                    .foregroundStyle(isSelected ? theme.accent : theme.muted)
            }
            .padding(.horizontal, Spacing.step2)
            .padding(.vertical, Spacing.step1)
            .frame(minWidth: 24, minHeight: 24)
            .background(theme.canvas.opacity(0.92), in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? theme.selectedBoundary : theme.graphNodeBoundary.opacity(0.35),
                    lineWidth: isSelected ? Stroke.loadBearing : Stroke.hairline
                )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("map.edge.\(edge.id)")
        .accessibilityLabel("Relationship: \(edge.type). \(edge.state.displayName).")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
