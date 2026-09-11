import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ProjectOS").font(.largeTitle.bold())
                    Text("Return to the state of your work, not the scrollback.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("New Project", systemImage: "plus") { environment.showCreateProject = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Create a new project")
            }
            .padding(28)

            if environment.projects.isEmpty {
                ContentUnavailableView("No Projects Yet", systemImage: "folder", description: Text("Create a project. Local work remains available without AI or a network."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(environment.projects) { project in
                    Button { environment.openProject(project) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "folder.fill").font(.title2).foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name).font(.headline)
                                Text(project.summary.isEmpty ? "No description" : project.summary).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Revision \(project.revision)").font(.caption).foregroundStyle(.secondary)
                                Text(project.updatedAt, style: .relative).font(.caption)
                            }
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(project.name)")
                }
            }
        }
        .sheet(isPresented: $environment.showCreateProject) { CreateProjectSheet() }
    }
}

private struct CreateProjectSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var summary = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Project").font(.title2.bold())
            TextField("Project name", text: $name)
            TextField("What should future-you understand?", text: $summary, axis: .vertical).lineLimit(3...6)
            Text("This project is stored locally. No AI setup is needed to create or browse it.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Create") { environment.createProject(name: name, summary: summary) }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 480)
    }
}
