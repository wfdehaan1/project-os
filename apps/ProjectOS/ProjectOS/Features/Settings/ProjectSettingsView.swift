import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var confirmDelete = false
    @State private var projectName = ""
    @State private var projectSummary = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Project Settings").font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: 10) {
                    Label("Project Identity", systemImage: "folder").font(.headline)
                    TextField("Name", text: $projectName)
                    TextField("Description", text: $projectSummary, axis: .vertical).lineLimit(2...5)
                    HStack { Spacer(); Button("Save Project Details") { environment.updateProject(name: projectName, summary: projectSummary) }.buttonStyle(.borderedProminent) }
                }.card()
                SourceListView().card()
                VStack(alignment: .leading, spacing: 10) {
                    Label("Recent Inference", systemImage: "waveform.path.ecg").font(.headline)
                    if environment.inferenceJobs.isEmpty {
                        Text("No inference requests recorded for this project.").foregroundStyle(.secondary)
                    }
                    ForEach(environment.inferenceJobs.prefix(8)) { job in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(job.purpose) · \(job.provider) · \(job.model) · \(job.status.rawValue)").font(.caption.bold())
                            if let route = job.configuredUpstreamRoute { Text("Pinned route: \(route)").font(.caption) }
                            if let actual = job.actualUpstreamProvider { Text("Returned route: \(actual)").font(.caption) }
                            if let cost = job.cost { Text(verbatim: "Returned usage: \(job.inputTokens.map(String.init) ?? "?") in / \(job.outputTokens.map(String.init) ?? "?") out · \(NSDecimalNumber(decimal: cost).stringValue) \(job.currency ?? "")").font(.caption) }
                            else { Text("Returned cost: unknown (not zero)").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }.card()
                VStack(alignment: .leading, spacing: 10) {
                    Label("Ownership and Recovery", systemImage: "externaldrive").font(.headline)
                    Text("Exports contain local project state, exact source text, transcript distinctions, proposal and change history, evidence, relations, and outcomes. Credentials and runtime caches are excluded.")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Export Project...", systemImage: "square.and.arrow.up") { environment.exportSelectedProject() }
                        Button("Restore as New Project...", systemImage: "square.and.arrow.down") { environment.restoreProject() }
                    }
                    Text("Restore validates the archive before creating a separate project copy. Existing projects are never overwritten.")
                        .font(.caption).foregroundStyle(.secondary)
                }.card()

                VStack(alignment: .leading, spacing: 10) {
                    Label("Delete Project", systemImage: "trash").font(.headline).foregroundStyle(.red)
                    Text("Deletion removes app-managed local content after cancelling active jobs. It does not remove exports, backups, local models, or data retained by an external provider.")
                        .foregroundStyle(.secondary)
                    Button("Permanently Delete Project", role: .destructive) { confirmDelete = true }
                }.card()
            }.padding(24).frame(maxWidth: 900, alignment: .leading)
        }
        .sheet(isPresented: $confirmDelete) { DeleteProjectSheet(isPresented: $confirmDelete) }
        .onAppear {
            projectName = environment.selectedProject?.name ?? ""
            projectSummary = environment.selectedProject?.summary ?? ""
        }
    }
}

private struct DeleteProjectSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var isPresented: Bool
    @State private var confirmation = ""

    private var required: String { "DELETE \(environment.selectedProject?.name ?? "")" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Permanently Delete Project?").font(.title2.bold())
            Text("Export is offered before deletion. Deletion removes ProjectOS-managed content, but not exports, backups, local models, or records retained by external providers.")
            Button("Export First...") { environment.exportSelectedProject() }
            Text("Type \(required) to confirm.").fontWeight(.semibold)
            TextField(required, text: $confirmation)
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Delete Local Project", role: .destructive) {
                    isPresented = false
                    environment.deleteSelectedProject(typedConfirmation: confirmation)
                }.disabled(confirmation != required)
            }
        }.padding(24).frame(width: 520)
    }
}
