import SwiftUI

/// The change log: every accepted change to Canonical State, newest first.
///
/// Changes are grouped by revision so an atomically accepted set reads as one
/// event rather than as several unrelated edits.
struct ChangeLogView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var query = ""

    private var matches: [ChangeRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return environment.changes }
        return environment.changes.filter { $0.summary.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Revisions in descending order, each with the changes it contains.
    private var revisions: [(revision: Int, changes: [ChangeRecord])] {
        Dictionary(grouping: matches, by: \.revision)
            .sorted { $0.key > $1.key }
            .map { (revision: $0.key, changes: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SurfaceHeader(eyebrow: "Record", title: "Change log") {
                LocalStorageStatus(detail: "\(environment.changes.count) accepted changes")
            } actions: {
                SearchField(scope: "Search changes", text: $query)
                    .frame(width: 220)
                Button("Undo latest") { environment.undoLatest() }
                    .buttonStyle(.posSecondary)
                    .disabled(environment.changes.isEmpty)
            }
            DecorativeDivider()

            if revisions.isEmpty {
                EmptyStateView(
                    title: query.isEmpty ? "No accepted changes yet" : "No matching changes",
                    message: query.isEmpty
                        ? "Accepting a change proposal, or saving a correction, records an entry here."
                        : "Nothing in the change log matches “\(query)”.",
                    systemImage: "clock.arrow.circlepath",
                    primary: query.isEmpty
                        ? .init(title: "Review proposals") { environment.show(.proposals) }
                        : .init(title: "Clear search") { query = "" }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.step4) {
                        ForEach(revisions, id: \.revision) { entry in
                            RevisionCard(revision: entry.revision, changes: entry.changes)
                        }
                    }
                    .padding(Spacing.step5)
                    .frame(maxWidth: Spacing.readableWidth, alignment: .leading)
                }
            }
        }
        .background(theme.canvas)
        .navigationTitle("Change log")
    }
}

/// One revision of Canonical State and everything it changed.
private struct RevisionCard: View {
    let revision: Int
    let changes: [ChangeRecord]

    @Environment(\.theme) private var theme

    private var timestamp: Date? { changes.map(\.createdAt).max() }
    private var isUndone: Bool { changes.allSatisfy(\.undone) }

    var body: some View {
        SectionCard(title: "Revision \(revision)", subtitle: subtitle) {
            RowList(items: changes) { change in
                RecordRow(
                    title: change.summary,
                    subtitle: detail(for: change)
                ) {
                    RowGlyph(
                        systemImage: change.undone ? "arrow.uturn.backward" : "checkmark",
                        tone: change.undone ? .muted : .success
                    )
                } trailing: {
                    Text(change.createdAt, style: .relative)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                }
            }
        } accessory: {
            if isUndone {
                StatusBadge(text: "Undone", symbol: "arrow.uturn.backward", tone: .muted)
            } else if changes.count > 1 {
                StatusBadge(text: "Accepted as one set", symbol: "square.stack", tone: .accent)
            }
        }
    }

    private var subtitle: String? {
        guard let timestamp else { return nil }
        return timestamp.formatted(date: .abbreviated, time: .shortened)
    }

    /// What the change did, stated from the before/after pair it recorded.
    private func detail(for change: ChangeRecord) -> String? {
        switch (change.beforeArtifact, change.afterArtifact) {
        case (nil, let after?): "Added \(after.kind.rawValue.lowercased())"
        case (let before?, nil): "Removed \(before.kind.rawValue.lowercased())"
        case (let before?, let after?) where before.state != after.state:
            "\(before.state.displayName) → \(after.state.displayName)"
        case (_?, let after?): "Updated \(after.kind.rawValue.lowercased())"
        default: nil
        }
    }
}
