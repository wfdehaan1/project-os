import SwiftUI

/// The state ledger: current accepted project state, grouped so that what
/// governs now reads first.
///
/// One view serves every artifact kind. The sidebar rows for Decisions,
/// Research, Questions, Tasks, and Topics are the same surface with the filter
/// preselected.
struct LedgerView: View {
    /// The kind selected from the sidebar, or `nil` for everything.
    let kind: ArtifactKind?

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var filter: LedgerFilter = .all
    @State private var query = ""
    @State private var selectedID: UUID?
    @State private var showNewRecord = false

    /// `All` plus one segment per kind.
    private enum LedgerFilter: Hashable {
        case all
        case kind(ArtifactKind)

        var title: String {
            switch self {
            case .all: "All"
            case .kind(let kind): kind.pluralName
            }
        }

        var artifactKind: ArtifactKind? {
            switch self {
            case .all: nil
            case .kind(let kind): kind
            }
        }

        static let allCases: [LedgerFilter] = [.all] + ArtifactKind.allCases.map(LedgerFilter.kind)
    }

    private var filtered: [ArtifactRecord] {
        environment.liveArtifacts
            .filter { filter.artifactKind == nil || $0.kind == filter.artifactKind }
            .filter { LedgerGrouping.matches($0, query: query) }
    }

    private var groups: [LedgerGroup] { LedgerGrouping.groups(for: filtered) }

    private var selected: ArtifactRecord? {
        selectedID.flatMap { environment.artifact(with: $0) }
    }

    var body: some View {
        HSplitView {
            ledger
                .frame(minWidth: 420)
            inspectorPane
                .frame(minWidth: 320, idealWidth: 380)
        }
        .background(theme.canvas)
        .navigationTitle(kind?.pluralName ?? "All records")
        .onAppear { filter = kind.map(LedgerFilter.kind) ?? .all }
        .onChange(of: kind) { _, newKind in
            filter = newKind.map(LedgerFilter.kind) ?? .all
            selectedID = nil
        }
        .sheet(isPresented: $showNewRecord) { NewArtifactSheet(isPresented: $showNewRecord) }
    }

    // MARK: - Ledger

    private var ledger: some View {
        VStack(spacing: 0) {
            SurfaceHeader(eyebrow: "Project state", title: kind?.pluralName ?? "All records") {
                LocalStorageStatus(detail: "\(filtered.count) shown")
            } actions: {
                Button {
                    showNewRecord = true
                } label: {
                    Label("New record", systemImage: "plus")
                }
                .buttonStyle(.posSecondary)
            }

            HStack(spacing: Spacing.step3) {
                SearchField(scope: "Search records", text: $query)
                    .frame(width: 190)
                SegmentedFilterBar(
                    items: LedgerFilter.allCases,
                    title: \.title,
                    count: { filterCount($0) },
                    selection: $filter
                )
            }
            .padding(.horizontal, Spacing.step5)
            .padding(.bottom, Spacing.step3)

            DecorativeDivider()

            if groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.step4) {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: Spacing.step2) {
                                FieldGroupLabel(text: group.title)
                                    .padding(.horizontal, Spacing.step3)
                                SurfaceContainer(padding: Spacing.step1) {
                                    RowList(items: group.records) { record in
                                        LedgerRow(
                                            record: record,
                                            provenance: environment.provenanceCount(for: record),
                                            isSelected: selectedID == record.id
                                        ) {
                                            selectedID = record.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(Spacing.step5)
                }
            }
        }
    }

    private func filterCount(_ filter: LedgerFilter) -> Int? {
        guard let kind = filter.artifactKind else { return environment.liveArtifacts.count }
        return environment.liveArtifacts.filter { $0.kind == kind }.count
    }

    @ViewBuilder
    private var emptyState: some View {
        if query.isEmpty {
            EmptyStateView(
                title: "Nothing accepted here yet",
                message: "Records enter the ledger when you accept a change proposal, or when you write one yourself.",
                systemImage: "square.stack.3d.up",
                primary: .init(title: "New record") { showNewRecord = true },
                secondary: .init(title: "Review proposals") { environment.show(.proposals) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyStateView(
                title: "No matching records",
                message: "Nothing in this view matches “\(query)”.",
                systemImage: "magnifyingglass",
                primary: .init(title: "Clear search") { query = "" }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorPane: some View {
        if let selected {
            ArtifactInspectorView(artifact: selected) { selectedID = nil }
                .id(selected.id)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                SurfaceHeader(title: "Pending proposals", status: {
                    Text("Not yet part of project state.")
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                })
                DecorativeDivider()
                if environment.actionableProposals.isEmpty {
                    EmptyStateView(
                        title: "Select a record",
                        message: "Inspect content, rationale, provenance, relationships, and history.",
                        systemImage: "sidebar.right"
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.step3) {
                            ForEach(environment.actionableProposals) { proposal in
                                ProposalCardView(proposal: proposal, isCompact: true)
                            }
                        }
                        .padding(Spacing.step3)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(theme.sidebar)
        }
    }
}

/// One accepted record in the ledger: type, title, meaningful state, when it
/// last changed, and how much provenance backs it.
private struct LedgerRow: View {
    let record: ArtifactRecord
    let provenance: Int
    let isSelected: Bool
    let select: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        RecordRow(
            title: record.title,
            subtitle: record.content,
            isSelected: isSelected,
            showsDisclosure: true,
            action: select
        ) {
            RowGlyph(systemImage: record.kind.symbolName, tone: record.kind.tone)
        } trailing: {
            // Metadata keeps its intrinsic width and drops the least essential
            // columns first, so the title always keeps a readable measure.
            ViewThatFits(in: .horizontal) {
                metadata(showsType: true, showsDate: true, showsProvenance: true)
                metadata(showsType: false, showsDate: true, showsProvenance: true)
                metadata(showsType: false, showsDate: false, showsProvenance: true)
                metadata(showsType: false, showsDate: false, showsProvenance: false)
            }
        }
    }

    private func metadata(showsType: Bool, showsDate: Bool, showsProvenance: Bool) -> some View {
        HStack(spacing: Spacing.step3) {
            if showsType {
                Text(record.kind.rawValue)
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            }
            StatusMark(
                text: record.state.displayName,
                symbol: record.state.symbolName,
                tone: record.state.tone
            )
            if showsDate {
                Text(record.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            }
            if showsProvenance {
                Text(provenance == 1 ? "1 source" : "\(provenance) sources")
                    .font(TypeRole.caption)
                    .foregroundStyle(provenance == 0 ? theme.warning : theme.muted)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A user-authored record. It enters accepted state with history, and never
/// pretends to have come from the agent.
private struct NewArtifactSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var isPresented: Bool

    @State private var kind: ArtifactKind = .topic
    @State private var title = ""
    @State private var content = ""
    @State private var rationale = ""
    @State private var subject = ""

    var body: some View {
        SheetScaffold(
            title: "New project record",
            subtitle: "A user-authored correction. It enters accepted state with history and is not attributed to AI.",
            confirmTitle: "Save",
            isConfirmEnabled: !title.isEmpty && !content.isEmpty,
            confirm: {
                environment.createArtifact(
                    kind: kind,
                    title: title,
                    content: content,
                    rationale: rationale,
                    decisionSubject: subject
                )
                isPresented = false
            },
            cancel: { isPresented = false }
        ) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                Picker("Kind", selection: $kind) {
                    ForEach(ArtifactKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                FormTextField(label: "Title", text: $title)
                FormTextField(label: "Content", text: $content, lineLimit: 4 ... 8)
                FormTextField(label: "Rationale (optional)", text: $rationale, lineLimit: 2 ... 4)
                if kind == .decision {
                    FormTextField(label: "Decision subject", text: $subject)
                }
            }
        }
        .frame(width: 560)
    }
}
