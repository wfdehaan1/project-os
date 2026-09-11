import SwiftUI

/// The open-project window: a persistent resizable sidebar and one main region.
///
/// The shell carries no account row, no permanent add-project action, and no
/// horizontal artifact tabs — the sidebar is the only navigation.
struct ProjectWorkspaceView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar()
                .navigationSplitViewColumnWidth(
                    min: Spacing.sidebarCollapsed,
                    ideal: Spacing.sidebarDefault,
                    max: 320
                )
        } detail: {
            destinationView
                // The split view measures the detail at near-zero width when it
                // works out the window's minimum size. Wrapped text is then one
                // character per line and thousands of points tall, so the whole
                // window overflowed vertically and clipped the sidebar. A real
                // minimum width keeps that measurement sane.
                .frame(minWidth: 480)
                .background(theme.canvas)
        }
        .sheet(isPresented: $environment.showAddSource) { AddSourceSheet() }
        .sheet(isPresented: $environment.showOutcome) { OutcomeFormView() }
        .sheet(item: $environment.evidenceInspection) { SourceInspectorSheet(evidence: $0) }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch environment.destination {
        case .overview: OverviewView()
        case .conversation: ConversationView()
        case .ledger(let kind): LedgerView(kind: kind)
        case .proposals: ProposalsView()
        case .changeLog: ChangeLogView()
        case .sources: SourcesView()
        case .settings: ProjectSettingsView()
        }
    }
}

/// Project switcher plus grouped destinations.
private struct WorkspaceSidebar: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProjectSwitcher()
                .padding(.horizontal, Spacing.step3)
                .padding(.vertical, Spacing.step3)
            DecorativeDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.step4) {
                    ForEach(WorkspaceNavigation.groups) { group in
                        VStack(alignment: .leading, spacing: Spacing.step1) {
                            if let title = group.title {
                                Text(title)
                                    .font(TypeRole.eyebrow)
                                    .foregroundStyle(theme.muted)
                                    .padding(.horizontal, Spacing.step2)
                                    .padding(.bottom, Spacing.step1)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            ForEach(group.destinations) { destination in
                                SidebarRow(
                                    destination: destination,
                                    badge: environment.badgeCount(for: destination),
                                    isSelected: environment.destination == destination
                                ) {
                                    environment.show(destination)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.step2)
                .padding(.vertical, Spacing.step3)
            }
            Spacer(minLength: 0)
            GenerationActivityIndicator()
                .padding(.horizontal, Spacing.step3)
                .padding(.bottom, Spacing.step3)
            DecorativeDivider()
            Button {
                environment.closeProject()
            } label: {
                Label("All Projects", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.posGhost)
            .padding(Spacing.step3)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.sidebar)
        .overlay(alignment: .trailing) { DecorativeDivider(axis: .vertical) }
    }
}

/// Project title plus a theme marker and disclosure. No miniature pile, and no
/// account or avatar treatment.
private struct ProjectSwitcher: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            ForEach(environment.projects) { project in
                Button(project.name) { environment.openProject(project) }
            }
            Divider()
            Button("All Projects") { environment.closeProject() }
        } label: {
            HStack(spacing: Spacing.step2) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.accent)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(environment.selectedProject?.name ?? "Project")
                        .font(TypeRole.label.weight(.semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(environment.themePreset.displayName)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: Spacing.step2)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(theme.muted)
            }
            .padding(.horizontal, Spacing.step2)
            .padding(.vertical, Spacing.step2)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(theme.essentialBoundary.opacity(0.45), lineWidth: Stroke.hairline)
        }
        .accessibilityLabel("Switch project. Current project \(environment.selectedProject?.name ?? "none").")
    }
}

/// One sidebar destination. The active row uses a selection fill, a selected
/// boundary marker, and weight — never colour alone.
private struct SidebarRow: View {
    let destination: WorkspaceDestination
    let badge: Int?
    let isSelected: Bool
    let select: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: select) {
            HStack(spacing: Spacing.step2) {
                Rectangle()
                    .fill(isSelected ? theme.selectedBoundary : .clear)
                    .frame(width: 2.5)
                    .accessibilityHidden(true)
                Image(systemName: destination.symbolName)
                    .imageScale(.small)
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? theme.accent : theme.muted)
                Text(destination.title)
                    .font(isSelected ? TypeRole.label.weight(.semibold) : TypeRole.label)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer(minLength: Spacing.step2)
                if let badge {
                    Text("\(badge)")
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                        .monospacedDigit()
                }
            }
            .padding(.trailing, Spacing.step2)
            .padding(.vertical, Spacing.step2 - 1)
            .background(isSelected ? theme.selection : .clear, in: RoundedRectangle(cornerRadius: Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(destination.title)
        .accessibilityIdentifier("sidebar.\(destination.id)")
        .accessibilityLabel(destination.title)
        // The count is a value, not part of the name, so the destination stays
        // addressable by its own title.
        .accessibilityValue(badge.map(String.init) ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The exact retained source text behind a citation, with the cited span
/// emphasised in place.
private struct SourceInspectorSheet: View {
    let evidence: EvidenceInspection

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private var highlightedText: AttributedString {
        var text = AttributedString(evidence.fullText)
        if let range = text.range(of: evidence.quote) {
            text[range].backgroundColor = .yellow.opacity(0.45)
            text[range].foregroundColor = .black
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step3) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.step1) {
                    Text(evidence.label)
                        .font(TypeRole.sectionTitle)
                        .foregroundStyle(theme.text)
                    HStack(spacing: Spacing.step2) {
                        StatusBadge(text: "Retained version \(evidence.version)", symbol: "doc.text", tone: .muted)
                        if evidence.aiAuthored {
                            StatusBadge(
                                text: "AI-authored · unverified",
                                symbol: "exclamationmark.triangle",
                                tone: .warning
                            )
                        }
                    }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.posPrimary)
                    .keyboardShortcut(.defaultAction)
            }
            DecorativeDivider()
            ScrollView {
                Text(highlightedText)
                    .font(TypeRole.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Spacing.step5)
        .frame(minWidth: 640, minHeight: 440)
        .background(theme.surfaceRaised)
    }
}
