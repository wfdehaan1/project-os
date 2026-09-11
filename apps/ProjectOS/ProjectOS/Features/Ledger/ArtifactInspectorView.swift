import SwiftUI

/// The shared accepted-artifact frame.
///
/// Every artifact type uses the same anatomy — type and status, current
/// content, rationale, relationships, provenance, history, then type-aware
/// actions — so nothing has to be relearned per type.
struct ArtifactInspectorView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var draft: ArtifactRecord
    @State private var relationType = "supports"
    @State private var relationTarget: UUID?
    @State private var confirmRemoval = false

    private let original: ArtifactRecord
    private let close: () -> Void

    init(artifact: ArtifactRecord, close: @escaping () -> Void) {
        original = artifact
        _draft = State(initialValue: artifact)
        self.close = close
    }

    /// Only the statuses that make sense for this type may be chosen.
    private var allowedStates: [ArtifactState] {
        switch draft.kind {
        case .topic, .research: [.current, .removed]
        case .decision: [.current, .superseded, .removed]
        case .openQuestion: [.open, .resolved, .dismissed, .removed]
        case .task: [.open, .inProgress, .blocked, .done, .removed]
        }
    }

    private var hasEdits: Bool {
        draft.title != original.title || draft.content != original.content || draft.state != original.state
    }

    private var relationshipTargets: [ArtifactRecord] {
        environment.liveArtifacts.filter { $0.id != draft.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            DecorativeDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.step4) {
                    contentSection
                    contextSection
                    provenanceSection
                    relationshipsSection
                    historySection
                }
                .padding(Spacing.step4)
            }
            DecorativeDivider()
            footer
        }
        .background(theme.surfaceRaised)
        .confirmationDialog(
            "Remove this record from project state?",
            isPresented: $confirmRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove record", role: .destructive) {
                environment.removeArtifact(draft)
                close()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The record leaves current state. Its history stays in the change log and can be undone.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.step3) {
            RowGlyph(systemImage: draft.kind.symbolName, tone: draft.kind.tone)
            VStack(alignment: .leading, spacing: Spacing.step1) {
                Text(draft.kind.rawValue)
                    .font(TypeRole.eyebrow)
                    .foregroundStyle(theme.muted)
                HStack(spacing: Spacing.step2) {
                    StatusBadge(
                        text: draft.state.displayName,
                        symbol: draft.state.symbolName,
                        tone: draft.state.tone
                    )
                    Text("Version \(draft.version)")
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                }
            }
            Spacer(minLength: Spacing.step2)
            IconButton(systemImage: "xmark", accessibilityLabel: "Close inspector", action: close)
        }
        .padding(Spacing.step4)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.step3) {
            FormTextField(label: "Title", text: $draft.title)
            FormTextEditor(label: "Current content", text: $draft.content, minHeight: 130)
            VStack(alignment: .leading, spacing: Spacing.step1) {
                Text("Status")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
                Picker("Status", selection: $draft.state) {
                    ForEach(allowedStates, id: \.self) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    private var contextSection: some View {
        let entries: [(String, String)] = [
            ("Rationale", draft.rationale),
            ("Decision subject", draft.decisionSubject),
            ("Certainty", draft.certainty),
            ("Limitations", draft.limitations),
        ].compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }

        if !entries.isEmpty {
            SectionCard(title: "Context", role: .surface) {
                VStack(alignment: .leading, spacing: Spacing.step2) {
                    ForEach(entries, id: \.0) { label, value in
                        MetaRow(label: label, value: value)
                    }
                }
            }
        }
    }

    private var provenanceSection: some View {
        SectionCard(title: "Provenance", role: .surface) {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                if draft.evidence.isEmpty {
                    InlineEmptyText(text: "No cited source. This is a user-authored record.")
                } else {
                    ForEach(draft.evidence) { evidence in
                        EvidenceChip(evidence: evidence) { environment.inspectEvidence(evidence) }
                    }
                }
            }
        }
    }

    private var relationshipsSection: some View {
        SectionCard(title: "Relationships", role: .surface) {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                if draft.relationships.isEmpty {
                    InlineEmptyText(text: "Not linked to another record yet.")
                } else {
                    ForEach(draft.relationships) { relation in
                        let target = relation.targetArtifactID.flatMap { environment.artifact(with: $0) }
                        RecordRow(
                            title: target?.title ?? "Missing target",
                            subtitle: relation.type
                        ) {
                            RowGlyph(
                                systemImage: "arrow.triangle.branch",
                                tone: target == nil ? .warning : .muted,
                                isFilled: false
                            )
                        }
                    }
                }

                DecorativeDivider()

                HStack(spacing: Spacing.step2) {
                    Picker("Type", selection: $relationType) {
                        ForEach(["supports", "concerns", "advances", "blocks", "supersedes"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)

                    Picker("Target", selection: $relationTarget) {
                        Text("Choose record").tag(nil as UUID?)
                        ForEach(relationshipTargets) { Text($0.title).tag($0.id as UUID?) }
                    }
                    .labelsHidden()

                    Button("Link") {
                        if let target = relationTarget {
                            environment.linkArtifact(draft, to: target, type: relationType)
                            relationTarget = nil
                        }
                    }
                    .buttonStyle(.posSecondary)
                    .disabled(relationTarget == nil)
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        let history = environment.history(for: draft)
        SectionCard(title: "History", role: .surface) {
            if history.isEmpty {
                InlineEmptyText(text: "No recorded changes yet.")
            } else {
                RowList(items: history) { change in
                    RecordRow(title: change.summary, subtitle: change.actor) {
                        Text("r\(change.revision)")
                            .font(TypeRole.code)
                            .foregroundStyle(theme.muted)
                            .frame(width: 44, alignment: .leading)
                    } trailing: {
                        Text(change.createdAt, style: .relative)
                            .font(TypeRole.caption)
                            .foregroundStyle(theme.muted)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.step2) {
            Button("Remove") { confirmRemoval = true }
                .buttonStyle(.posDestructive)
            Spacer(minLength: Spacing.step2)
            if hasEdits {
                Button("Discard") { draft = original }
                    .buttonStyle(.posGhost)
            }
            Button("Save correction") {
                environment.saveArtifact(draft, summary: "Corrected \(draft.kind.rawValue): \(draft.title)")
            }
            .buttonStyle(.posPrimary)
            .disabled(!hasEdits)
        }
        .padding(Spacing.step4)
    }
}
