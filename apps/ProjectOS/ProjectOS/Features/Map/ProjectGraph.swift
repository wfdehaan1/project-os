import Foundation

/// Which layer a node belongs to.
///
/// Accepted nodes are project state. Proposed nodes are not state yet and are
/// drawn so they can never be mistaken for it. Provenance nodes are the
/// conversations that produced state, and stay hidden until asked for.
enum GraphNodeRole: String, Hashable {
    case accepted
    case proposed
    case provenance
}

/// One node on the map.
struct GraphNode: Identifiable, Hashable {
    let id: UUID
    let role: GraphNodeRole
    /// `nil` for a conversation provenance node.
    let kind: ArtifactKind?
    let title: String
    let detail: String
    /// `nil` for a conversation provenance node.
    let state: ArtifactState?

    /// Whether this node describes state the project has moved past.
    var isHistorical: Bool {
        guard let state else { return false }
        return ProjectGraphBuilder.historicalStates.contains(state)
    }

    /// Type first, then title. The outline, every column, and every rebuild use
    /// this one order, which is what keeps a record in the same place between
    /// sessions rather than wherever a layout pass happened to put it.
    var sortKey: String { "\(kind?.rawValue ?? "Conversation")\u{1}\(title.lowercased())" }
}

/// How far a relationship can still be trusted.
///
/// Age never weakens a relationship — only the state of its endpoints and the
/// availability of the evidence behind it do.
enum RelationshipState: String, Hashable, CaseIterable {
    /// Both endpoints are current state.
    case current
    /// Still canonical, but something about it has to be looked at.
    case needsReview
    /// The record holding it has itself been superseded or dismissed.
    case historical
    /// Part of a proposal, and therefore not project state at all.
    case proposed

    var displayName: String {
        switch self {
        case .current: "Current"
        case .needsReview: "Needs review"
        case .historical: "Historical"
        case .proposed: "Proposed"
        }
    }

    /// A distinct shape per state, so the map never carries status in colour
    /// or line style alone.
    var symbolName: String {
        switch self {
        case .current: "arrow.forward"
        case .needsReview: "exclamationmark.triangle"
        case .historical: "clock.arrow.circlepath"
        case .proposed: "sparkles"
        }
    }
}

/// One typed relationship, drawn as an edge and inspectable in its own right.
struct GraphEdge: Identifiable, Hashable {
    let id: String
    let sourceID: UUID
    let targetID: UUID
    let type: String
    let state: RelationshipState
    /// Why this relationship needs review, when it does.
    let reviewReason: String?

    static func identifier(source: UUID, type: String, target: UUID) -> String {
        "\(source.uuidString)|\(type)|\(target.uuidString)"
    }
}

/// What is selected on the map. The canvas and the outline share it, so the two
/// views are always looking at the same thing.
enum MapSelection: Hashable {
    case node(UUID)
    case relationship(String)
}

/// A focused view over the same project state.
enum MapLens: String, CaseIterable, Identifiable, Hashable {
    case currentState
    case unresolvedWork
    case decisionHistory
    case provenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentState: "Current state"
        case .unresolvedWork: "Unresolved work"
        case .decisionHistory: "Decision history"
        case .provenance: "Provenance"
        }
    }

    var explanation: String {
        switch self {
        case .currentState: "Accepted records that describe the project now."
        case .unresolvedWork: "Open questions, tasks, and research, with what they touch."
        case .decisionHistory: "Decisions and what replaced them, with their supporting records."
        case .provenance: "Accepted records and the conversations they came from."
        }
    }

    /// Decision history is about supersession, so it shows past state whether or
    /// not the historical layer is switched on.
    var forcesHistorical: Bool { self == .decisionHistory }
}

/// The nodes and edges of one map view, and the questions the surfaces ask of
/// them.
struct ProjectGraph: Equatable {
    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []

    var isEmpty: Bool { nodes.isEmpty }

    /// Every node in the one stable order the map uses everywhere.
    var ordered: [GraphNode] { nodes.sorted { $0.sortKey < $1.sortKey } }

    func node(_ id: UUID) -> GraphNode? { nodes.first { $0.id == id } }

    func edge(_ id: String) -> GraphEdge? { edges.first { $0.id == id } }

    func outgoing(_ id: UUID) -> [GraphEdge] {
        edges.filter { $0.sourceID == id }.sorted { $0.id < $1.id }
    }

    func incoming(_ id: UUID) -> [GraphEdge] {
        edges.filter { $0.targetID == id }.sorted { $0.id < $1.id }
    }

    var needsReviewCount: Int { edges.filter { $0.state == .needsReview }.count }

    /// Reads a relationship as a sentence, for the Relationship Inspector and
    /// for screen readers.
    func meaning(of edge: GraphEdge) -> String {
        let source = node(edge.sourceID)?.title ?? "A removed record"
        let target = node(edge.targetID)?.title ?? "a removed record"
        switch edge.type {
        case "supports": return "\(source) supports \(target)."
        case "concerns": return "\(source) raises a concern about \(target)."
        case "advances": return "\(source) advances \(target)."
        case "blocks": return "\(source) blocks \(target)."
        case "supersedes": return "\(source) replaces \(target)."
        case "informs": return "\(source) is where \(target) came from."
        default: return "\(source) \(edge.type) \(target)."
        }
    }
}

/// Turns accepted state, proposals, and conversations into the graph one lens
/// asks for.
///
/// Every rule the Project Map claims — what counts as current, when a
/// relationship needs review, what a lens includes — lives here rather than in
/// a view, so each one can be asserted in a test.
enum ProjectGraphBuilder {
    /// Statuses that describe state the project has moved past. A removed
    /// record is not historical; it is gone, and never appears at all.
    static let historicalStates: [ArtifactState] = [.superseded, .dismissed]

    /// Statuses that represent live, unfinished work.
    static let unresolvedStates: [ArtifactState] = [.open, .inProgress, .blocked]

    static func build(
        artifacts: [ArtifactRecord],
        conversations: [ConversationRecord] = [],
        proposals: [ProposalRecord] = [],
        /// The sources still retained on this Mac. `nil` means provenance was
        /// not checked, so no relationship is faulted for missing evidence.
        retainedSourceIDs: Set<UUID>? = nil,
        lens: MapLens = .currentState,
        showsHistorical: Bool = false,
        showsProposed: Bool = false,
        focusID: UUID? = nil
    ) -> ProjectGraph {
        let live = artifacts.filter { $0.state != .removed }
        // Keeps removed records resolvable, so a relationship pointing at one
        // can say so instead of silently vanishing.
        let allByID = Dictionary(artifacts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let includesHistorical = showsHistorical || lens.forcesHistorical

        var scope = scopeIDs(lens: lens, live: live, includesHistorical: includesHistorical)

        // A canonical relationship pointing at state the project has moved past
        // is exactly what someone needs to see, so it pulls its endpoint into
        // view even under the current-state lens.
        for artifact in live where scope.contains(artifact.id) {
            for relation in artifact.relationships {
                guard let targetID = relation.targetArtifactID else { continue }
                let resolved = relationshipState(
                    source: artifact,
                    targetID: targetID,
                    artifacts: allByID,
                    retainedSourceIDs: retainedSourceIDs
                )
                if resolved.state == .needsReview, allByID[targetID]?.state != .removed {
                    scope.insert(targetID)
                }
            }
        }

        var nodes: [GraphNode] = []
        var edges: [GraphEdge] = []

        for artifact in live where scope.contains(artifact.id) {
            nodes.append(
                GraphNode(
                    id: artifact.id,
                    role: .accepted,
                    kind: artifact.kind,
                    title: artifact.title,
                    detail: artifact.content,
                    state: artifact.state
                )
            )
        }

        for artifact in live where scope.contains(artifact.id) {
            for relation in artifact.relationships {
                guard let targetID = relation.targetArtifactID, scope.contains(targetID) else { continue }
                let resolved = relationshipState(
                    source: artifact,
                    targetID: targetID,
                    artifacts: allByID,
                    retainedSourceIDs: retainedSourceIDs
                )
                edges.append(
                    GraphEdge(
                        id: GraphEdge.identifier(source: artifact.id, type: relation.type, target: targetID),
                        sourceID: artifact.id,
                        targetID: targetID,
                        type: relation.type,
                        state: resolved.state,
                        reviewReason: resolved.reason
                    )
                )
            }
        }

        // Conversations are provenance, not state. They appear when provenance
        // is what is being asked for, or beside the one artifact in focus.
        if lens == .provenance || focusID != nil {
            for conversation in conversations {
                guard let researchID = conversation.researchID, scope.contains(researchID) else { continue }
                nodes.append(
                    GraphNode(
                        id: conversation.id,
                        role: .provenance,
                        kind: nil,
                        title: conversation.title,
                        detail: "Conversation",
                        state: nil
                    )
                )
                edges.append(
                    GraphEdge(
                        id: GraphEdge.identifier(source: conversation.id, type: "informs", target: researchID),
                        sourceID: conversation.id,
                        targetID: researchID,
                        type: "informs",
                        state: .current,
                        reviewReason: nil
                    )
                )
            }
        }

        if showsProposed {
            let actionable = proposals.filter { $0.lifecycle.isActionable }
            let proposalIDs = Set(actionable.map(\.id))
            for proposal in actionable {
                nodes.append(
                    GraphNode(
                        id: proposal.id,
                        role: .proposed,
                        kind: proposal.kind,
                        title: proposal.title,
                        detail: proposal.content,
                        state: proposal.proposedState ?? proposal.kind.initialState
                    )
                )
            }
            for proposal in actionable {
                // What the proposal would change, drawn to the record it targets.
                if let targetID = proposal.targetID, scope.contains(targetID) {
                    let type = proposal.operation == .supersede ? "supersedes" : "updates"
                    edges.append(
                        GraphEdge(
                            id: GraphEdge.identifier(source: proposal.id, type: type, target: targetID),
                            sourceID: proposal.id,
                            targetID: targetID,
                            type: type,
                            state: .proposed,
                            reviewReason: nil
                        )
                    )
                }
                for relation in proposal.relationships {
                    let targetID = relation.targetArtifactID ?? relation.targetProposalID
                    guard let targetID, scope.contains(targetID) || proposalIDs.contains(targetID) else { continue }
                    edges.append(
                        GraphEdge(
                            id: GraphEdge.identifier(source: proposal.id, type: relation.type, target: targetID),
                            sourceID: proposal.id,
                            targetID: targetID,
                            type: relation.type,
                            state: .proposed,
                            reviewReason: nil
                        )
                    )
                }
            }
        }

        var graph = ProjectGraph(nodes: deduplicated(nodes), edges: deduplicated(edges))
        if let focusID { graph = focused(graph, on: focusID) }
        return graph
    }

    /// Age never weakens a relationship; only the state of its endpoints and
    /// the availability of the evidence behind it do.
    static func relationshipState(
        source: ArtifactRecord,
        targetID: UUID,
        artifacts: [UUID: ArtifactRecord],
        retainedSourceIDs: Set<UUID>?
    ) -> (state: RelationshipState, reason: String?) {
        if historicalStates.contains(source.state) {
            return (
                .historical,
                "\(source.title) is \(source.state.displayName.lowercased()), so this relationship records past state."
            )
        }
        guard let target = artifacts[targetID] else {
            return (.needsReview, "The record at the other end is no longer in project state.")
        }
        if target.state == .removed {
            return (.needsReview, "\(target.title) was removed from project state.")
        }
        if historicalStates.contains(target.state) {
            return (
                .needsReview,
                "\(target.title) is \(target.state.displayName.lowercased()). This relationship stays canonical until you review it."
            )
        }
        if let retainedSourceIDs, let missing = missingEvidence(for: source, retained: retainedSourceIDs) {
            return (.needsReview, missing)
        }
        return (.current, nil)
    }

    /// A record whose cited source is no longer retained cannot be checked, so
    /// what it is connected to has to be looked at again.
    private static func missingEvidence(for artifact: ArtifactRecord, retained: Set<UUID>) -> String? {
        let unavailable = artifact.evidence.filter { $0.sourceType == "source" && !retained.contains($0.sourceID) }
        guard !unavailable.isEmpty else { return nil }
        return "A source cited by \(artifact.title) is no longer retained, so this relationship cannot be checked against it."
    }

    // MARK: - Lens scope

    private static func scopeIDs(
        lens: MapLens,
        live: [ArtifactRecord],
        includesHistorical: Bool
    ) -> Set<UUID> {
        let visible = live.filter { includesHistorical || !historicalStates.contains($0.state) }

        switch lens {
        case .currentState, .provenance:
            return Set(visible.map(\.id))

        case .unresolvedWork:
            let seeds = visible.filter { unresolvedStates.contains($0.state) }
            return Set(seeds.map(\.id)).union(neighbours(of: Set(seeds.map(\.id)), within: visible))

        case .decisionHistory:
            // Decisions keep their whole lineage here, superseded included,
            // because supersession is the point of this lens.
            let decisions = live.filter { $0.kind == .decision }
            let ids = Set(decisions.map(\.id))
            return ids.union(neighbours(of: ids, within: live))
        }
    }

    /// Everything one hop from a seed set, in either direction.
    private static func neighbours(of seeds: Set<UUID>, within records: [ArtifactRecord]) -> Set<UUID> {
        var found: Set<UUID> = []
        let available = Set(records.map(\.id))
        for record in records {
            for relation in record.relationships {
                guard let targetID = relation.targetArtifactID else { continue }
                if seeds.contains(record.id), available.contains(targetID) { found.insert(targetID) }
                if seeds.contains(targetID), available.contains(record.id) { found.insert(record.id) }
            }
        }
        return found
    }

    /// Focus mode: the selection and its immediate neighbours. Two hops are
    /// never included on their own.
    private static func focused(_ graph: ProjectGraph, on focusID: UUID) -> ProjectGraph {
        guard graph.node(focusID) != nil else { return graph }
        var keep: Set<UUID> = [focusID]
        for edge in graph.edges {
            if edge.sourceID == focusID { keep.insert(edge.targetID) }
            if edge.targetID == focusID { keep.insert(edge.sourceID) }
        }
        return ProjectGraph(
            nodes: graph.nodes.filter { keep.contains($0.id) },
            edges: graph.edges.filter { keep.contains($0.sourceID) && keep.contains($0.targetID) }
        )
    }

    private static func deduplicated(_ nodes: [GraphNode]) -> [GraphNode] {
        var seen: Set<UUID> = []
        return nodes.filter { seen.insert($0.id).inserted }
    }

    private static func deduplicated(_ edges: [GraphEdge]) -> [GraphEdge] {
        var seen: Set<String> = []
        return edges.filter { seen.insert($0.id).inserted }
    }
}
