import SwiftUI
import XCTest
@testable import ProjectOS

/// Tests for the pure presentation logic the UI is built on: Pile Cover
/// composition, the Overview briefing, and ledger grouping. These have no view
/// dependency, which is the point of keeping them out of the views.
final class PresentationLogicTests: XCTestCase {
    private let projectID = UUID()

    // MARK: - Pile Cover

    func testCoverCountsGoverningSupersededQuestionsAndProposalSets() {
        let governing = artifact(kind: .decision, state: .current, title: "Pumped wastewater")
        let superseded = artifact(kind: .decision, state: .superseded, title: "Gravity drainage")
        let removed = artifact(kind: .decision, state: .removed, title: "Abandoned")
        let openQuestion = artifact(kind: .openQuestion, state: .open, title: "Invert level?")
        let resolvedQuestion = artifact(kind: .openQuestion, state: .resolved, title: "Pump model?")

        let spec = PileCoverComposer.spec(
            artifacts: [governing, superseded, removed, openQuestion, resolvedQuestion],
            proposals: [],
            changes: []
        )

        XCTAssertEqual(spec.governingCount, 1)
        XCTAssertEqual(spec.supersededCount, 1)
        XCTAssertEqual(spec.decisions.count, 2, "A removed decision leaves the pile entirely.")
        XCTAssertEqual(spec.questions, 1, "Only unresolved questions sit on the ground.")
        XCTAssertEqual(spec.proposalSets, 0)
    }

    func testCoverOrdersDecisionsByFirstAppearanceNotByRecentEdit() {
        let first = artifact(kind: .decision, state: .current, title: "First", updatedAt: .distantFuture)
        let second = artifact(kind: .decision, state: .current, title: "Second", updatedAt: .distantPast)

        // The change log is newest-first, as the store returns it.
        let changes = [
            change(revision: 7, artifact: second),
            change(revision: 2, artifact: first),
        ]

        let spec = PileCoverComposer.spec(
            artifacts: [first, second],
            proposals: [],
            changes: changes
        )

        XCTAssertEqual(
            spec.decisions.map(\.id),
            [first.id, second.id],
            "A decision edited most recently must not jump ahead of an older one."
        )
    }

    func testOnlyActionableProposalsProduceOneMarkPerDependencySet() {
        let root = proposal(lifecycle: .pending)
        let dependent = proposal(lifecycle: .pending, dependencyIDs: [root.id])
        let deferred = proposal(lifecycle: .deferred)
        let accepted = proposal(lifecycle: .accepted)
        let rejected = proposal(lifecycle: .rejected)

        let spec = PileCoverComposer.spec(
            artifacts: [],
            proposals: [root, dependent, deferred, accepted, rejected],
            changes: []
        )

        XCTAssertEqual(
            spec.proposalSets,
            2,
            "The dependent set counts once, the deferred one counts, and reviewed ones do not."
        )
    }

    func testLegendUsesTheExactRenderedCounts() {
        let spec = PileCoverSpec(
            decisions: [
                .init(id: UUID(), isSuperseded: false),
                .init(id: UUID(), isSuperseded: false),
                .init(id: UUID(), isSuperseded: true),
            ],
            questions: 1,
            proposalSets: 3
        )
        XCTAssertEqual(spec.legend, "2 governing · 1 superseded · 1 question · 3 proposal sets")
    }

    // MARK: - Overview briefing

    func testRecommendationFromAnEarlierRevisionNeedsRecapRatherThanBeingShownStale() {
        let project = project(revision: 9)
        let stale = recommendation(originatingRevision: 4)

        let briefing = OverviewBriefingBuilder.build(
            project: project,
            artifacts: [],
            changes: [],
            changesSinceLastVisit: [],
            proposals: [],
            recommendation: stale,
            outcomes: [],
            messages: []
        )

        XCTAssertEqual(briefing.nextAction, .needsRecap)
    }

    func testRecommendationAtTheCurrentRevisionIsShown() {
        let project = project(revision: 9)
        let current = recommendation(originatingRevision: 9)

        let briefing = OverviewBriefingBuilder.build(
            project: project,
            artifacts: [],
            changes: [],
            changesSinceLastVisit: [],
            proposals: [],
            recommendation: current,
            outcomes: [],
            messages: []
        )

        XCTAssertEqual(briefing.nextAction, .current(current))
    }

    func testDismissedRecommendationIsTreatedAsNotGenerated() {
        var dismissed = recommendation(originatingRevision: 3)
        dismissed.isDismissed = true

        let briefing = OverviewBriefingBuilder.build(
            project: project(revision: 3),
            artifacts: [],
            changes: [],
            changesSinceLastVisit: [],
            proposals: [],
            recommendation: dismissed,
            outcomes: [],
            messages: []
        )

        XCTAssertEqual(briefing.nextAction, .none)
    }

    func testReturnLineMeasuresTimeSinceTheNewestProjectActivity() {
        let now = Date()
        let nineDaysAgo = now.addingTimeInterval(-9 * 24 * 3600)
        let decision = artifact(kind: .decision, state: .current, title: "Pumped wastewater")

        let briefing = OverviewBriefingBuilder.build(
            project: project(revision: 1),
            artifacts: [decision],
            changes: [change(revision: 1, artifact: decision, createdAt: nineDaysAgo)],
            changesSinceLastVisit: [],
            proposals: [],
            recommendation: nil,
            outcomes: [],
            messages: [],
            now: now
        )

        XCTAssertEqual(briefing.returnLine, "Back after 9 days")
    }

    func testReturnLineForAProjectWithNoActivityYet() {
        let briefing = OverviewBriefingBuilder.build(
            project: project(revision: 0),
            artifacts: [],
            changes: [],
            changesSinceLastVisit: [],
            proposals: [],
            recommendation: nil,
            outcomes: [],
            messages: []
        )

        XCTAssertEqual(briefing.returnLine, "New project")
    }

    // MARK: - Ledger grouping

    func testLedgerPutsGoverningStateFirstAndDropsRemovedRecords() {
        let governing = artifact(kind: .decision, state: .current, title: "Pumped wastewater")
        let openTask = artifact(kind: .task, state: .inProgress, title: "Confirm pump lift")
        let superseded = artifact(kind: .decision, state: .superseded, title: "Gravity drainage")
        let removed = artifact(kind: .topic, state: .removed, title: "Abandoned topic")

        let groups = LedgerGrouping.groups(for: [removed, superseded, openTask, governing])

        XCTAssertEqual(groups.map(\.title), ["Governing now", "Open work", "Recently changed"])
        XCTAssertEqual(groups[0].records.map(\.id), [governing.id])
        XCTAssertEqual(groups[1].records.map(\.id), [openTask.id])
        XCTAssertEqual(groups[2].records.map(\.id), [superseded.id])
        XCTAssertFalse(
            groups.flatMap(\.records).contains { $0.id == removed.id },
            "A removed record never appears in the ledger."
        )
    }

    func testEmptyGroupsAreOmitted() {
        let governing = artifact(kind: .decision, state: .current, title: "Pumped wastewater")
        let groups = LedgerGrouping.groups(for: [governing])
        XCTAssertEqual(groups.map(\.title), ["Governing now"])
    }

    func testSupersededRecordsAgeOutOfRecentlyChanged() {
        let now = Date()
        var old = artifact(kind: .decision, state: .superseded, title: "Gravity drainage")
        old.updatedAt = now.addingTimeInterval(-40 * 24 * 3600)

        let groups = LedgerGrouping.groups(for: [old], now: now)

        XCTAssertEqual(groups.map(\.title), ["Earlier state"])
    }

    func testSearchMatchesTitleContentAndRationale() {
        var record = artifact(kind: .decision, state: .current, title: "Pumped wastewater")
        record.content = "Macerator pump to the existing sewer."
        record.rationale = "Gravity drainage is not viable."

        XCTAssertTrue(LedgerGrouping.matches(record, query: "macerator"))
        XCTAssertTrue(LedgerGrouping.matches(record, query: "GRAVITY"))
        XCTAssertTrue(LedgerGrouping.matches(record, query: "   "), "A blank query matches everything.")
        XCTAssertFalse(LedgerGrouping.matches(record, query: "electrical"))
    }

    // MARK: - Theme resolution

    func testIncreaseContrastReplacesLoadBearingRolesOnly() {
        let normal = ThemeResolver.resolve(preset: .studioPaper, colorScheme: .light, increasedContrast: false)
        let contrast = ThemeResolver.resolve(preset: .studioPaper, colorScheme: .light, increasedContrast: true)

        XCTAssertNotEqual(normal.focusIndicator, contrast.focusIndicator)
        XCTAssertNotEqual(normal.essentialBoundary, contrast.essentialBoundary)
        XCTAssertEqual(normal.canvas, contrast.canvas, "Structural surfaces keep their value.")
        XCTAssertEqual(normal.text, contrast.text)
    }

    func testEveryPresetDefinesEveryAppearance() {
        for preset in ThemePreset.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let theme = ThemeResolver.resolve(preset: preset, colorScheme: scheme, increasedContrast: false)
                XCTAssertEqual(theme.preset, preset)
                XCTAssertNotEqual(
                    theme.canvas,
                    theme.text,
                    "\(preset.rawValue) \(scheme) must not render text on its own canvas colour."
                )
            }
        }
    }

    // MARK: - Fixtures

    private func project(revision: Int) -> ProjectRecord {
        ProjectRecord(
            id: projectID,
            name: "Garden Office Utilities",
            summary: "Route utilities to a garden office.",
            createdAt: Date(),
            updatedAt: Date(),
            revision: revision,
            previousVisitRevision: 0
        )
    }

    private func artifact(
        kind: ArtifactKind,
        state: ArtifactState,
        title: String,
        updatedAt: Date = Date()
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
            evidence: [],
            version: 1,
            updatedAt: updatedAt
        )
    }

    private func change(
        revision: Int,
        artifact: ArtifactRecord,
        createdAt: Date = Date()
    ) -> ChangeRecord {
        ChangeRecord(
            id: UUID(),
            projectID: projectID,
            revision: revision,
            summary: "Added \(artifact.kind.rawValue): \(artifact.title)",
            beforeArtifact: nil,
            afterArtifact: artifact,
            createdAt: createdAt,
            undone: false
        )
    }

    private func proposal(
        lifecycle: ProposalLifecycle,
        dependencyIDs: [UUID] = []
    ) -> ProposalRecord {
        ProposalRecord(
            id: UUID(),
            projectID: projectID,
            originatingRevision: 1,
            kind: .decision,
            title: "Proposed decision",
            content: "",
            rationale: nil,
            decisionSubject: nil,
            evidence: [],
            dependencyIDs: dependencyIDs,
            lifecycle: lifecycle,
            createdAt: Date()
        )
    }

    private func recommendation(originatingRevision: Int) -> RecommendationRecord {
        RecommendationRecord(
            id: UUID(),
            projectID: projectID,
            text: "Confirm pump lift and service access before trench work begins.",
            supportingRecords: [],
            uncertainty: nil,
            originatingRevision: originatingRevision,
            createdAt: Date(),
            isDismissed: false
        )
    }
}
