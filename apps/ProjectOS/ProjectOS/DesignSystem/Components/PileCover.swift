import SwiftUI

/// What a Pile Cover draws, in the order it must draw it.
///
/// Kept separate from the view so composition is a pure, testable function of
/// project state, and so the Project Library and the Overview masthead share
/// one renderer.
struct PileCoverSpec: Equatable {
    struct DecisionMark: Equatable, Identifiable {
        let id: UUID
        let isSuperseded: Bool
    }

    /// Decisions in immutable first-appearance order.
    var decisions: [DecisionMark] = []
    /// Unresolved Questions, which sit at ground level and never repack the pile.
    var questions: Int = 0
    /// One mark per actionable proposal set.
    var proposalSets: Int = 0

    var governingCount: Int { decisions.filter { !$0.isSuperseded }.count }
    var supersededCount: Int { decisions.filter(\.isSuperseded).count }

    var isEmpty: Bool { decisions.isEmpty && questions == 0 && proposalSets == 0 }

    /// The legend text, using the exact rendered counts.
    var legend: String {
        var parts = ["\(governingCount) governing"]
        if supersededCount > 0 { parts.append("\(supersededCount) superseded") }
        parts.append("\(questions) \(questions == 1 ? "question" : "questions")")
        if proposalSets > 0 {
            parts.append("\(proposalSets) proposal \(proposalSets == 1 ? "set" : "sets")")
        }
        return parts.joined(separator: " · ")
    }
}

/// Builds a `PileCoverSpec` from accepted project state.
///
/// First-appearance order comes from the change log, which is the only record
/// of when an artifact entered Canonical State. Artifacts with no change
/// history fall back to their update time, so a restored or imported project
/// still composes deterministically.
enum PileCoverComposer {
    static func spec(
        artifacts: [ArtifactRecord],
        proposals: [ProposalRecord],
        changes: [ChangeRecord]
    ) -> PileCoverSpec {
        var firstAppearance: [UUID: Int] = [:]
        // `changes` arrives newest-first, so a later assignment is an earlier revision.
        for change in changes {
            if let id = change.afterArtifact?.id ?? change.beforeArtifact?.id {
                firstAppearance[id] = change.revision
            }
        }

        let decisions = artifacts
            .filter { $0.kind == .decision && $0.state != .removed }
            .sorted { lhs, rhs in
                switch (firstAppearance[lhs.id], firstAppearance[rhs.id]) {
                case let (left?, right?) where left != right: left < right
                case (nil, _?): false
                case (_?, nil): true
                default: (lhs.updatedAt, lhs.id.uuidString) < (rhs.updatedAt, rhs.id.uuidString)
                }
            }
            .map { PileCoverSpec.DecisionMark(id: $0.id, isSuperseded: $0.state == .superseded) }

        let questions = artifacts.filter { $0.kind == .openQuestion && $0.state == .open }.count

        // A set is actionable when it contains a member still awaiting review.
        // Accepted, rejected, and invalidated members never keep a mark alive.
        let actionable = proposals.filter { $0.lifecycle.isActionable }
        let proposalSets = Set(actionable.map { setIdentity(for: $0, within: actionable) }).count

        return PileCoverSpec(decisions: decisions, questions: questions, proposalSets: proposalSets)
    }

    /// A proposal's set is the root it depends on; a proposal with no
    /// dependencies is its own set.
    private static func setIdentity(for proposal: ProposalRecord, within pool: [ProposalRecord]) -> UUID {
        var seen: Set<UUID> = [proposal.id]
        var current = proposal
        while let parentID = current.dependencyIDs.first,
              !seen.contains(parentID),
              let parent = pool.first(where: { $0.id == parentID }) {
            seen.insert(parentID)
            current = parent
        }
        return current.id
    }
}

/// The project cover: a local, deterministic, offline vector drawing of
/// accepted project state.
///
/// Geometry rules from the design spine:
/// 1. Governing Decisions are solid blocks placed bottom-up, filling each
///    course before starting a new one.
/// 2. Mark size never encodes duration, importance, effort, or actor.
/// 3. A placed block never moves. Supersession restyles it in place.
/// 4. Unresolved Questions sit at ground level to the right with a restrained
///    alternating tilt, and never repack the Decision blocks.
/// 5. One dashed mark per actionable proposal set floats above the pile.
/// 6. Bare ground plus Questions is the valid new-project state.
/// 7. Overflow scales the whole composition; it never clips or reorders.
struct PileCoverView: View {
    let spec: PileCoverSpec

    @Environment(\.theme) private var theme

    /// Blocks per course. A constant, because a capacity that grew with the
    /// decision count would move blocks that are already placed.
    private static let courseCapacity = 8
    private static let blockSize = CGSize(width: 26, height: 13)
    private static let blockGap: CGFloat = 3
    private static let questionSize: CGFloat = 11
    private static let proposalSize: CGFloat = 13
    private static let groundInset: CGFloat = 6

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let layout = PileCoverLayout(spec: spec)
            let scale = min(
                size.width / max(layout.contentSize.width, 1),
                size.height / max(layout.contentSize.height, 1),
                1.6
            )
            let drawnSize = CGSize(
                width: layout.contentSize.width * scale,
                height: layout.contentSize.height * scale
            )
            context.translateBy(
                x: (size.width - drawnSize.width) / 2,
                y: (size.height - drawnSize.height) / 2
            )
            context.scaleBy(x: scale, y: scale)
            draw(layout: layout, in: &context)
        }
        .accessibilityElement()
        .accessibilityLabel("Project cover. \(spec.legend).")
    }

    private func draw(layout: PileCoverLayout, in context: inout GraphicsContext) {
        // The ground line.
        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: layout.groundY))
        ground.addLine(to: CGPoint(x: layout.contentSize.width, y: layout.groundY))
        context.stroke(ground, with: .color(theme.pileGround), lineWidth: 1)

        for block in layout.decisionBlocks {
            let shape = Path(roundedRect: block.rect, cornerRadius: 2)
            if block.isSuperseded {
                // Outlined and hatched in place, so supersession reads without colour.
                context.stroke(shape, with: .color(theme.pileDecisionSuperseded), lineWidth: 1)
                var hatch = Path()
                var x = block.rect.minX + 3
                while x < block.rect.maxX {
                    hatch.move(to: CGPoint(x: x, y: block.rect.maxY))
                    hatch.addLine(to: CGPoint(x: x + block.rect.height, y: block.rect.minY))
                    x += 4
                }
                // Clip on a copy so the hatch never bleeds into later marks.
                var hatchContext = context
                hatchContext.clip(to: shape)
                hatchContext.stroke(hatch, with: .color(theme.pileDecisionSuperseded.opacity(0.7)), lineWidth: 0.6)
            } else {
                context.fill(shape, with: .color(theme.pileDecision))
            }
        }

        for question in layout.questionMarks {
            var copy = context
            copy.translateBy(x: question.center.x, y: question.center.y)
            copy.rotate(by: .degrees(question.tilt))
            let rect = CGRect(
                x: -Self.questionSize / 2,
                y: -Self.questionSize / 2,
                width: Self.questionSize,
                height: Self.questionSize
            )
            copy.stroke(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(theme.pileQuestion), lineWidth: 1)
        }

        for proposal in layout.proposalMarks {
            let rect = CGRect(
                x: proposal.x - Self.proposalSize / 2,
                y: proposal.y - Self.proposalSize / 2,
                width: Self.proposalSize,
                height: Self.proposalSize
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 1.5),
                with: .color(theme.pileProposal),
                style: StrokeStyle(lineWidth: 1, dash: [2.5, 2])
            )
        }
    }

    /// Pure geometry, separated so it can be reasoned about without a canvas.
    fileprivate struct PileCoverLayout {
        struct Block { let rect: CGRect; let isSuperseded: Bool }
        struct QuestionMark { let center: CGPoint; let tilt: Double }
        struct ProposalMark { let x: CGFloat; let y: CGFloat }

        let decisionBlocks: [Block]
        let questionMarks: [QuestionMark]
        let proposalMarks: [ProposalMark]
        let groundY: CGFloat
        let contentSize: CGSize

        init(spec: PileCoverSpec) {
            let block = PileCoverView.blockSize
            let gap = PileCoverView.blockGap
            let capacity = PileCoverView.courseCapacity

            let courseCount = max(1, Int(ceil(Double(spec.decisions.count) / Double(capacity))))
            let pileWidth = CGFloat(capacity) * block.width + CGFloat(capacity - 1) * gap
            let pileHeight = CGFloat(courseCount) * block.height + CGFloat(courseCount - 1) * gap

            // Room above the pile for floating proposal marks.
            let proposalBand: CGFloat = spec.proposalSets > 0 ? PileCoverView.proposalSize + gap * 2 : 0
            let questionBand = CGFloat(spec.questions > 0 ? PileCoverView.questionSize : 0)
            let questionColumnWidth = spec.questions > 0
                ? CGFloat(spec.questions) * (PileCoverView.questionSize + gap) + PileCoverView.groundInset
                : 0

            let ground = proposalBand + pileHeight
            groundY = ground
            contentSize = CGSize(
                width: pileWidth + questionColumnWidth,
                height: ground + questionBand / 2 + 1
            )

            decisionBlocks = spec.decisions.enumerated().map { index, mark in
                let course = index / capacity
                let slot = index % capacity
                let rect = CGRect(
                    x: CGFloat(slot) * (block.width + gap),
                    y: ground - CGFloat(course + 1) * block.height - CGFloat(course) * gap,
                    width: block.width,
                    height: block.height
                )
                return Block(rect: rect, isSuperseded: mark.isSuperseded)
            }

            questionMarks = (0 ..< spec.questions).map { index in
                QuestionMark(
                    center: CGPoint(
                        x: pileWidth + PileCoverView.groundInset
                            + CGFloat(index) * (PileCoverView.questionSize + gap)
                            + PileCoverView.questionSize / 2,
                        y: ground - PileCoverView.questionSize / 2
                    ),
                    // A restrained repeating alternation, not randomness.
                    tilt: index.isMultiple(of: 2) ? -7 : 7
                )
            }

            proposalMarks = (0 ..< spec.proposalSets).map { index in
                let total = CGFloat(spec.proposalSets)
                let spacing = PileCoverView.proposalSize + gap * 2
                let start = pileWidth / 2 - (total - 1) * spacing / 2
                return ProposalMark(
                    x: start + CGFloat(index) * spacing,
                    y: proposalBand / 2
                )
            }
        }
    }
}

/// Cover plus its legend, the pairing used on Overview and on a Project Card.
struct PileCoverPanel: View {
    let spec: PileCoverSpec
    var minimumHeight: CGFloat = Spacing.mastheadMinimumHeight
    var accessory: AnyView?

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceContainer(role: .tint, padding: Spacing.step4) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                if let accessory {
                    accessory
                }
                PileCoverView(spec: spec)
                    .frame(minHeight: minimumHeight - Spacing.step6, maxHeight: .infinity)
                Text(spec.legend)
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: minimumHeight)
    }
}

#if DEBUG
#Preview {
    ThemedPreview {
        let marks = (0 ..< 11).map { index in
            PileCoverSpec.DecisionMark(id: UUID(), isSuperseded: index == 4)
        }
        PileCoverPanel(spec: PileCoverSpec(decisions: marks, questions: 2, proposalSets: 3))
            .frame(width: 320)
            .padding(Spacing.step5)
    }
}
#endif
