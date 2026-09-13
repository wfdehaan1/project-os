import XCTest
@testable import ProjectOS

/// Tests for the Project Map's rules: what each lens includes, when a
/// relationship stops being trustworthy, how the proposed and historical layers
/// stay separate from accepted state, and why the layout does not move.
final class ProjectMapTests: XCTestCase {
    private let projectID = UUID()

    // MARK: - Lenses and layers

    func testCurrentStateLensLeavesOutHistoricalAndRemovedRecords() {
        let governing = artifact(kind: .decision, state: .current, title: "Pumped wastewater")
        let superseded = artifact(kind: .decision, state: .superseded, title: "Gravity drainage")
        let dismissed = artifact(kind: .openQuestion, state: .dismissed, title: "Rainwater reuse?")
        let removed = artifact(kind: .topic, state: .removed, title: "Abandoned topic")

        let graph = ProjectGraphBuilder.build(artifacts: [governing, superseded, dismissed, removed])

        XCTAssertEqual(graph.nodes.map(\.id), [governing.id])
    }

    func testHistoricalLayerAddsPastStateButARemovedRecordNeverComesBack() {
        let governing = artifact(kind: .decision, state: .current, title: "Pumped wastewater")
        let superseded = artifact(kind: .decision, state: .superseded, title: "Gravity drainage")
        let removed = artifact(kind: .topic, state: .removed, title: "Abandoned topic")

        let graph = ProjectGraphBuilder.build(
            artifacts: [governing, superseded, removed],
            showsHistorical: true
        )

        XCTAssertEqual(Set(graph.nodes.map(\.id)), [governing.id, superseded.id])
        XCTAssertTrue(
            graph.node(superseded.id)?.isHistorical == true,
            "A superseded record stays marked as past state so it cannot read as governing."
        )
    }

    func testDecisionHistoryLensShowsSupersessionWithoutTheHistoricalLayerSwitchedOn() {
        let superseded = artifact(kind: .decision, state: .superseded, title: "Gravity drainage")
        let governing = artifact(
            kind: .decision,
            state: .current,
            title: "Pumped wastewater",
            relationships: [relation(type: "supersedes", to: superseded.id)]
        )

        let graph = ProjectGraphBuilder.build(
            artifacts: [governing, superseded],
            lens: .decisionHistory,
            showsHistorical: false
        )

        XCTAssertEqual(Set(graph.nodes.map(\.id)), [governing.id, superseded.id])
        XCTAssertEqual(graph.outgoing(governing.id).map(\.type), ["supersedes"])
    }

    func testUnresolvedWorkLensKeepsOpenWorkAndWhatItTouches() {
        let governing = artifact(kind: .decision, state: .current, title: "Pumped wastewater")
        let unrelated = artifact(kind: .topic, state: .current, title: "Electricity")
        let question = artifact(
            kind: .openQuestion,
            state: .open,
            title: "Required pump lift?",
            relationships: [relation(type: "concerns", to: governing.id)]
        )

        let graph = ProjectGraphBuilder.build(
            artifacts: [governing, unrelated, question],
            lens: .unresolvedWork
        )

        XCTAssertEqual(Set(graph.nodes.map(\.id)), [question.id, governing.id])
        XCTAssertFalse(
            graph.nodes.contains { $0.id == unrelated.id },
            "A record no open work touches is not unresolved work."
        )
    }

    // MARK: - Relationship state

    func testARelationshipPointingAtSupersededStateNeedsReviewAndKeepsItsEndpointInView() {
        let superseded = artifact(kind: .decision, state: .superseded, title: "Gravity drainage")
        let research = artifact(
            kind: .research,
            state: .done,
            title: "Site measurements",
            relationships: [relation(type: "supports", to: superseded.id)]
        )

        // The current-state lens, with the historical layer off.
        let graph = ProjectGraphBuilder.build(artifacts: [research, superseded])

        XCTAssertTrue(
            graph.nodes.contains { $0.id == superseded.id },
            "A canonical relationship pointing at past state must stay visible; that is the thing needing attention."
        )
        let edge = graph.outgoing(research.id).first
        XCTAssertEqual(edge?.state, .needsReview)
        XCTAssertNotNil(edge?.reviewReason)
        XCTAssertEqual(graph.needsReviewCount, 1)
    }

    func testARelationshipHeldByASupersededRecordIsHistoricalRatherThanNeedingReview() {
        let governing = artifact(kind: .decision, state: .current, title: "Pumped wastewater")
        let superseded = artifact(
            kind: .decision,
            state: .superseded,
            title: "Gravity drainage",
            relationships: [relation(type: "concerns", to: governing.id)]
        )

        let graph = ProjectGraphBuilder.build(
            artifacts: [governing, superseded],
            showsHistorical: true
        )

        XCTAssertEqual(graph.outgoing(superseded.id).first?.state, .historical)
    }

    func testAgeAloneNeverWeakensARelationship() {
        let target = artifact(kind: .task, state: .open, title: "Dig trench")
        var old = artifact(
            kind: .decision,
            state: .current,
            title: "Pumped wastewater",
            relationships: [relation(type: "advances", to: target.id)]
        )
        old.updatedAt = Date(timeIntervalSince1970: 0)

        let graph = ProjectGraphBuilder.build(artifacts: [old, target])

        XCTAssertEqual(
            graph.outgoing(old.id).first?.state,
            .current,
            "A relationship between two current records stays current no matter how long ago it was made."
        )
    }

    func testUnavailableRetainedEvidenceMakesARelationshipNeedReview() {
        let target = artifact(kind: .task, state: .open, title: "Dig trench")
        let missingSourceID = UUID()
        let decision = artifact(
            kind: .decision,
            state: .current,
            title: "Pumped wastewater",
            evidence: [
                EvidenceRecord(
                    id: UUID(),
                    sourceType: "source",
                    sourceID: missingSourceID,
                    version: 1,
                    quote: "The office sits below the house sewer.",
                    aiAuthored: false
                )
            ],
            relationships: [relation(type: "advances", to: target.id)]
        )

        let checked = ProjectGraphBuilder.build(
            artifacts: [decision, target],
            retainedSourceIDs: []
        )
        XCTAssertEqual(checked.outgoing(decision.id).first?.state, .needsReview)

        let unchecked = ProjectGraphBuilder.build(artifacts: [decision, target], retainedSourceIDs: nil)
        XCTAssertEqual(
            unchecked.outgoing(decision.id).first?.state,
            .current,
            "Without a retained-source list, provenance is simply not checked rather than assumed broken."
        )
    }

    // MARK: - Proposal layer

    func testProposalsAreAbsentUntilTheProposedLayerIsAskedForAndStayMarkedAsNotState() {
        let governing = artifact(kind: .decision, state: .current, title: "Pumped wastewater")
        let pending = proposal(
            lifecycle: .pending,
            title: "Use a macerating pump",
            operation: .supersede,
            targetID: governing.id
        )
        let rejected = proposal(lifecycle: .rejected, title: "Route power separately")

        let accepted = ProjectGraphBuilder.build(artifacts: [governing], proposals: [pending, rejected])
        XCTAssertEqual(accepted.nodes.map(\.id), [governing.id])

        let withLayer = ProjectGraphBuilder.build(
            artifacts: [governing],
            proposals: [pending, rejected],
            showsProposed: true
        )
        XCTAssertEqual(Set(withLayer.nodes.map(\.id)), [governing.id, pending.id])
        XCTAssertEqual(withLayer.node(pending.id)?.role, .proposed)
        XCTAssertEqual(
            withLayer.outgoing(pending.id).first?.state,
            .proposed,
            "A proposed relationship is never drawn as accepted state."
        )
        XCTAssertFalse(
            withLayer.nodes.contains { $0.id == rejected.id },
            "A reviewed proposal belongs to proposal history, not the map."
        )
    }

    // MARK: - Provenance

    func testConversationsAreHiddenUntilProvenanceIsAskedFor() {
        let research = artifact(kind: .research, state: .done, title: "Drainage research")
        let conversation = ConversationRecord(
            id: UUID(),
            projectID: projectID,
            title: "Drainage options",
            createdAt: Date(),
            updatedAt: Date(),
            researchID: research.id
        )

        let current = ProjectGraphBuilder.build(artifacts: [research], conversations: [conversation])
        XCTAssertEqual(current.nodes.map(\.id), [research.id])

        let provenance = ProjectGraphBuilder.build(
            artifacts: [research],
            conversations: [conversation],
            lens: .provenance
        )
        XCTAssertEqual(Set(provenance.nodes.map(\.id)), [research.id, conversation.id])
        XCTAssertEqual(provenance.node(conversation.id)?.role, .provenance)
        XCTAssertEqual(provenance.incoming(research.id).first?.type, "informs")
    }

    // MARK: - Focus

    func testFocusKeepsImmediateNeighboursAndNeverReachesTwoHops() {
        let far = artifact(kind: .task, state: .open, title: "Request separation requirements")
        let neighbour = artifact(
            kind: .decision,
            state: .current,
            title: "Coordinate utilities in one trench",
            relationships: [relation(type: "advances", to: far.id)]
        )
        let centre = artifact(
            kind: .decision,
            state: .current,
            title: "Pumped wastewater",
            relationships: [relation(type: "advances", to: neighbour.id)]
        )

        let graph = ProjectGraphBuilder.build(artifacts: [centre, neighbour, far], focusID: centre.id)

        XCTAssertEqual(Set(graph.nodes.map(\.id)), [centre.id, neighbour.id])
        XCTAssertFalse(
            graph.nodes.contains { $0.id == far.id },
            "Two hops are never pulled in automatically."
        )
    }

    // MARK: - Reading a relationship

    func testARelationshipReadsAsASentence() {
        let target = artifact(kind: .openQuestion, state: .open, title: "Required pump lift?")
        let source = artifact(
            kind: .decision,
            state: .current,
            title: "Pumped wastewater",
            relationships: [relation(type: "blocks", to: target.id)]
        )

        let graph = ProjectGraphBuilder.build(artifacts: [source, target])
        let edge = try? XCTUnwrap(graph.outgoing(source.id).first)

        XCTAssertEqual(edge.map(graph.meaning(of:)), "Pumped wastewater blocks Required pump lift?.")
    }

    // MARK: - Layout

    func testLayoutIsIdenticalForIdenticalStateSoTheMapDoesNotMoveBetweenSessions() {
        let graph = sampleGraph()

        let first = GraphLayout.layout(graph)
        let shuffled = ProjectGraph(nodes: graph.nodes.reversed(), edges: graph.edges.reversed())
        let second = GraphLayout.layout(shuffled)

        XCTAssertEqual(
            first.positions,
            second.positions,
            "The same project state must produce the same map whatever order the records arrive in."
        )
    }

    func testLayoutReadsLeftToRightFromWhatIsKnownToWhatIsLeftToDo() {
        let graph = sampleGraph()
        let layout = GraphLayout.layout(graph)

        let research = graph.nodes.first { $0.kind == .research }!
        let decision = graph.nodes.first { $0.kind == .decision }!
        let task = graph.nodes.first { $0.kind == .task }!

        XCTAssertLessThan(layout.positions[research.id]!.x, layout.positions[decision.id]!.x)
        XCTAssertLessThan(layout.positions[decision.id]!.x, layout.positions[task.id]!.x)
    }

    func testNodesNeverOverlap() {
        let layout = GraphLayout.layout(sampleGraph())
        let frames = layout.positions.map { CGRect(origin: $0.value, size: GraphLayout.nodeSize) }

        for (index, frame) in frames.enumerated() {
            for other in frames[(index + 1)...] {
                XCTAssertFalse(frame.intersects(other), "Two records were drawn on top of each other.")
            }
        }
    }

    func testAnEmptyGraphHasNothingToLayOut() {
        let layout = GraphLayout.layout(ProjectGraph())
        XCTAssertTrue(layout.positions.isEmpty)
        XCTAssertEqual(layout.size, .zero)
    }

    func testAConnectionLeavesTheSourceAndArrivesAtTheTarget() {
        let source = CGRect(x: 0, y: 0, width: 212, height: 96)
        let target = CGRect(x: 400, y: 0, width: 212, height: 96)

        let connection = GraphConnection(from: source, to: target)

        XCTAssertEqual(connection.start.x, source.maxX, "The line leaves the side facing the target.")
        XCTAssertEqual(connection.end.x, target.minX, "The line stops at the target rather than crossing it.")
        XCTAssertGreaterThan(connection.midpoint.x, source.maxX)
        XCTAssertLessThan(connection.midpoint.x, target.minX)
    }

    // MARK: - Outline parity

    func testTheOutlineOrdersByTypeThenTitleSoARecordKeepsItsPlace() {
        let graph = sampleGraph()

        let titles = graph.ordered.map(\.title)

        XCTAssertEqual(titles, graph.nodes.sorted { $0.sortKey < $1.sortKey }.map(\.title))
        XCTAssertEqual(
            Set(graph.ordered.map(\.id)),
            Set(graph.nodes.map(\.id)),
            "The outline shows every record the canvas does."
        )
    }

    // MARK: - Fixtures

    private func sampleGraph() -> ProjectGraph {
        let task = artifact(kind: .task, state: .open, title: "Confirm specification")
        let question = artifact(kind: .openQuestion, state: .open, title: "Required pump lift?")
        let decision = artifact(
            kind: .decision,
            state: .current,
            title: "Pumped wastewater",
            relationships: [relation(type: "advances", to: task.id), relation(type: "blocks", to: question.id)]
        )
        let research = artifact(
            kind: .research,
            state: .done,
            title: "Site measurements",
            relationships: [relation(type: "supports", to: decision.id)]
        )
        let topic = artifact(
            kind: .topic,
            state: .current,
            title: "Drainage",
            relationships: [relation(type: "concerns", to: decision.id)]
        )
        return ProjectGraphBuilder.build(artifacts: [topic, research, decision, question, task])
    }

    private func relation(type: String, to targetID: UUID) -> TypedRelationship {
        TypedRelationship(id: UUID(), type: type, targetArtifactID: targetID, targetProposalID: nil)
    }

    private func artifact(
        kind: ArtifactKind,
        state: ArtifactState,
        title: String,
        evidence: [EvidenceRecord] = [],
        relationships: [TypedRelationship] = []
    ) -> ArtifactRecord {
        ArtifactRecord(
            id: UUID(),
            projectID: projectID,
            kind: kind,
            title: title,
            content: "",
            state: state,
            rationale: nil,
            decisionSubject: nil,
            evidence: evidence,
            relationships: relationships,
            version: 1,
            updatedAt: Date()
        )
    }

    private func proposal(
        lifecycle: ProposalLifecycle,
        title: String,
        operation: ProposalOperation = .create,
        targetID: UUID? = nil
    ) -> ProposalRecord {
        ProposalRecord(
            id: UUID(),
            projectID: projectID,
            originatingRevision: 1,
            operation: operation,
            targetID: targetID,
            kind: .decision,
            title: title,
            content: "",
            rationale: nil,
            decisionSubject: nil,
            evidence: [],
            lifecycle: lifecycle,
            createdAt: Date()
        )
    }
}
