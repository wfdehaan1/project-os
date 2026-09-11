import SwiftUI

/// The source material a project has imported.
///
/// A source is retained exactly as pasted. Including one in context is a
/// deliberate act, so selection lives on the row rather than being implied.
struct SourcesView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var query = ""
    @State private var expandedID: UUID?

    private var matches: [SourceRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return environment.sources }
        return environment.sources.filter {
            $0.label.localizedCaseInsensitiveContains(trimmed)
                || $0.text.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SurfaceHeader(eyebrow: "Record", title: "Sources") {
                LocalStorageStatus(detail: "\(environment.sources.count) retained")
            } actions: {
                if !environment.sources.isEmpty {
                    SearchField(scope: "Search sources", text: $query)
                        .frame(width: 220)
                }
                Button {
                    environment.showAddSource = true
                } label: {
                    Label("Paste source", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.posPrimary)
            }
            DecorativeDivider()

            if matches.isEmpty {
                EmptyStateView(
                    title: environment.sources.isEmpty ? "No source material yet" : "No matching sources",
                    message: environment.sources.isEmpty
                        ? "Paste labelled text to make it selectable context. The exact Unicode text is retained on this Mac."
                        : "No source label or body matches “\(query)”.",
                    systemImage: "doc.on.doc",
                    primary: environment.sources.isEmpty
                        ? .init(title: "Paste source") { environment.showAddSource = true }
                        : .init(title: "Clear search") { query = "" }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.step3) {
                        ForEach(matches) { source in
                            SourceCard(
                                source: source,
                                isIncluded: environment.contextSelection.sourceIDs.contains(source.id),
                                isExpanded: expandedID == source.id,
                                toggleInclusion: { toggleInclusion(source) },
                                toggleExpansion: {
                                    withAnimation(Motion.standard) {
                                        expandedID = expandedID == source.id ? nil : source.id
                                    }
                                }
                            )
                        }
                    }
                    .padding(Spacing.step5)
                    .frame(maxWidth: Spacing.readableWidth, alignment: .leading)
                }
            }
        }
        .background(theme.canvas)
        .navigationTitle("Sources")
    }

    private func toggleInclusion(_ source: SourceRecord) {
        if environment.contextSelection.sourceIDs.contains(source.id) {
            environment.contextSelection.sourceIDs.remove(source.id)
        } else {
            environment.contextSelection.sourceIDs.insert(source.id)
        }
    }
}

/// One retained source: label, import metadata, context inclusion, and the
/// original text on demand.
private struct SourceCard: View {
    let source: SourceRecord
    let isIncluded: Bool
    let isExpanded: Bool
    let toggleInclusion: () -> Void
    let toggleExpansion: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceContainer(padding: Spacing.step3) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                HStack(spacing: Spacing.step3) {
                    Toggle("Include in context", isOn: Binding(
                        get: { isIncluded },
                        set: { _ in toggleInclusion() }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .accessibilityLabel("Include \(source.label) in context")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.label)
                            .font(TypeRole.body.weight(.medium))
                            .foregroundStyle(theme.text)
                        Text("Version \(source.version) · \(source.text.count) characters · added \(source.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(TypeRole.caption)
                            .foregroundStyle(theme.muted)
                    }

                    Spacer(minLength: Spacing.step2)

                    if isIncluded {
                        StatusBadge(text: "In context", symbol: "checkmark", tone: .accent)
                    }

                    Button(isExpanded ? "Hide text" : "Show text", action: toggleExpansion)
                        .buttonStyle(.posGhost)
                }

                if isExpanded {
                    ScrollView {
                        Text(source.text)
                            .font(TypeRole.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.step3)
                    }
                    .frame(maxHeight: 320)
                    .background(theme.tint, in: RoundedRectangle(cornerRadius: Radius.sm))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The compact source picker used inside the conversation's context preview.
struct SourceInclusionList: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step2) {
            HStack {
                FieldGroupLabel(text: "Source material")
                Spacer()
                Button {
                    environment.showAddSource = true
                } label: {
                    Label("Paste source", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.posGhost)
            }
            if environment.sources.isEmpty {
                InlineEmptyText(text: "No sources yet. Paste labelled text to make it selectable context.")
            } else {
                ForEach(environment.sources) { source in
                    Toggle(isOn: Binding(
                        get: { environment.contextSelection.sourceIDs.contains(source.id) },
                        set: { included in
                            if included {
                                environment.contextSelection.sourceIDs.insert(source.id)
                            } else {
                                environment.contextSelection.sourceIDs.remove(source.id)
                            }
                        }
                    )) {
                        HStack {
                            Text(source.label).font(TypeRole.caption)
                            Spacer()
                            Text("v\(source.version)")
                                .font(TypeRole.caption)
                                .foregroundStyle(theme.muted)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
}

struct AddSourceSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var text = ""

    var body: some View {
        SheetScaffold(
            title: "Paste source material",
            subtitle: "The exact Unicode text is retained on this Mac and can be cited as provenance.",
            confirmTitle: "Save",
            isConfirmEnabled: !label.isEmpty && !text.isEmpty,
            confirm: { environment.addSource(label: label, text: text) },
            cancel: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                FormTextField(label: "Label", text: $label, prompt: "e.g. Garden office notes")
                FormTextEditor(
                    label: "Text",
                    text: $text,
                    minHeight: 240,
                    footnote: "\(text.count) / 250,000 characters"
                )
            }
        }
        .frame(width: 660)
    }
}
