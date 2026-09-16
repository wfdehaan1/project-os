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
        // New Project is reachable from the switcher while a project is open, and
        // the ⌘N command sets the same flag, so the sheet has to exist on this
        // surface too — not only on the Project Library.
        .sheet(isPresented: $environment.showCreateProject) { CreateProjectSheet() }
        .sheet(isPresented: $environment.showAddSource) { AddSourceSheet() }
        .sheet(isPresented: $environment.showOutcome) { OutcomeFormView() }
        .sheet(item: $environment.evidenceInspection) { SourceInspectorSheet(evidence: $0) }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch environment.destination {
        case .overview: OverviewView()
        case .map: ProjectMapView()
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
                                    title: destination.title,
                                    symbolName: destination.symbolName,
                                    badge: environment.badgeCount(for: destination),
                                    isSelected: environment.destination == destination,
                                    identifier: "sidebar.\(destination.id)"
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
            Button("New Project") { environment.showCreateProject = true }
            Button("All Projects") { environment.closeProject() }
        } label: {
            HStack(spacing: Spacing.step2) {
                // The marker stands for the project's theme, so it reads as a
                // swatch with its own boundary rather than a bare dot.
                RoundedRectangle(cornerRadius: 5)
                    .fill(theme.accent)
                    .frame(width: 18, height: 18)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(theme.essentialBoundary, lineWidth: Stroke.hairline)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.selectedProject?.name ?? "Project")
                        .font(TypeRole.label.weight(.semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(environment.themePreset.displayName)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: Spacing.step2)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(theme.muted)
            }
            .padding(.horizontal, Spacing.step2)
            .padding(.vertical, Spacing.step2 - 2)
            // The row spans the sidebar, as the mockup's full-width switcher does.
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            // The chrome lives on the label, so what is styled is what is drawn.
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(theme.essentialBoundary, lineWidth: Stroke.hairline)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        // `.borderlessButton` renders native pull-down chrome on macOS 26: it
        // draws its own leading chevron, ignores a hidden menu indicator, and
        // discards this label. `.button` plus a plain button style draws the
        // label as written.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityIdentifier("workspace.project-switcher")
        .accessibilityLabel("Switch project. Current project \(environment.selectedProject?.name ?? "none").")
        // Theme belongs in the value, so the control stays addressable by name.
        .accessibilityValue(environment.themePreset.displayName)
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
                    // Text kept from the web stays traceable to its page, and
                    // says plainly that it is a copy from a moment in time.
                    if let origin = evidence.origin {
                        HStack(spacing: Spacing.step2) {
                            Image(systemName: "globe")
                                .imageScale(.small)
                                .accessibilityHidden(true)
                            Text("Read from \(origin.url.host ?? origin.url.absoluteString) on \(origin.fetchedAt.formatted(date: .abbreviated, time: .shortened)). The live page may have changed since.")
                            Link(destination: origin.url) {
                                Label("Open original page", systemImage: "arrow.up.right.square")
                            }
                            .help(origin.url.absoluteString)
                        }
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
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
