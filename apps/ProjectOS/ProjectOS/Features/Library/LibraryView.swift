import SwiftUI

/// The Project Library.
///
/// Projects are recognisable without becoming dashboards: a card is a cover and
/// a title, nothing more. Browsing, searching, and opening a project are all
/// local and never look like they invoked inference.
struct LibraryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme
    @State private var query = ""

    private var matches: [ProjectRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return environment.projects }
        return environment.projects.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.summary.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            DecorativeDivider()
            content
        }
        .background(theme.canvas)
        .sheet(isPresented: $environment.showCreateProject) { CreateProjectSheet() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.step4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.step1) {
                    // The wordmark orients the window; the surface title names
                    // what is on it.
                    Text("ProjectOS")
                        .font(TypeRole.eyebrow)
                        .foregroundStyle(theme.muted)
                    Text("Project Library")
                        .font(TypeRole.title)
                        .foregroundStyle(theme.text)
                    Text("Projects saved on this Mac.")
                        .font(TypeRole.body)
                        .foregroundStyle(theme.muted)
                }
                Spacer(minLength: Spacing.step4)
                HStack(spacing: Spacing.step2) {
                    Button("Restore project…") { environment.restoreProject() }
                        .buttonStyle(.posSecondary)
                    Button {
                        environment.showCreateProject = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                    .buttonStyle(.posPrimary)
                    .accessibilityLabel("Create a new project")
                }
            }
            if !environment.projects.isEmpty {
                SearchField(scope: "Search projects", text: $query)
                    .frame(maxWidth: 320)
            }
        }
        .padding(Spacing.step6)
    }

    @ViewBuilder
    private var content: some View {
        if environment.projects.isEmpty {
            EmptyStateView(
                title: "No projects yet",
                message: "Create a project to start a record. Local work stays available without AI or a network.",
                systemImage: "square.stack.3d.up",
                primary: .init(title: "New Project") { environment.showCreateProject = true },
                secondary: .init(title: "Restore project…") { environment.restoreProject() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if matches.isEmpty {
            EmptyStateView(
                title: "No matching projects",
                message: "No project name or description matches “\(query)”.",
                systemImage: "magnifyingglass",
                primary: .init(title: "Clear search") { query = "" }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: Spacing.step4)],
                    alignment: .leading,
                    spacing: Spacing.step4
                ) {
                    ForEach(matches) { project in
                        ProjectCard(
                            project: project,
                            cover: environment.coverSpec(for: project)
                        ) {
                            environment.openProject(project)
                        }
                    }
                }
                .padding(Spacing.step6)
            }
        }
    }
}

/// Pile Cover plus project title. One focus and hover target for the whole
/// card, and no dashboard metadata.
private struct ProjectCard: View {
    let project: ProjectRecord
    let cover: PileCoverSpec
    let open: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                PileCoverView(spec: cover)
                    .frame(height: 108)
                    .padding(Spacing.step3)
                    .background(theme.tint, in: RoundedRectangle(cornerRadius: Radius.md))
                Text(project.name)
                    .font(TypeRole.heading)
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.step3)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(
                        isHovering ? theme.selectedBoundary : theme.essentialBoundary.opacity(0.45),
                        lineWidth: isHovering ? Stroke.loadBearing : Stroke.hairline
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(Motion.quick, value: isHovering)
        .accessibilityLabel("Open \(project.name). \(cover.legend).")
    }
}

private struct CreateProjectSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var name = ""
    @State private var summary = ""

    var body: some View {
        SheetScaffold(
            title: "New Project",
            subtitle: "Stored locally. No AI setup is needed to create or browse a project.",
            confirmTitle: "Create",
            isConfirmEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            confirm: { environment.createProject(name: name, summary: summary) },
            cancel: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                FormTextField(label: "Project name", text: $name)
                FormTextField(
                    label: "What should future-you understand?",
                    text: $summary,
                    lineLimit: 3 ... 6
                )
            }
        }
        .frame(width: 480)
    }
}
