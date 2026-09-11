import SwiftUI

/// Project settings: identity, the inference record, ownership and recovery,
/// and — separated at the bottom — deletion.
struct ProjectSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var confirmDelete = false
    @State private var projectName = ""
    @State private var projectSummary = ""

    private var hasIdentityEdits: Bool {
        projectName != environment.selectedProject?.name
            || projectSummary != environment.selectedProject?.summary
    }

    var body: some View {
        VStack(spacing: 0) {
            SurfaceHeader(eyebrow: "Record", title: "Project Settings", status: {
                LocalStorageStatus(detail: "Revision \(environment.selectedProject?.revision ?? 0)")
            })
            DecorativeDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.step4) {
                    identityCard
                    inferenceCard
                    ownershipCard
                    deletionCard
                }
                .padding(Spacing.step5)
                .frame(maxWidth: Spacing.readableWidth, alignment: .leading)
            }
        }
        .background(theme.canvas)
        .navigationTitle("Project Settings")
        .sheet(isPresented: $confirmDelete) { DeleteProjectSheet(isPresented: $confirmDelete) }
        .onAppear {
            projectName = environment.selectedProject?.name ?? ""
            projectSummary = environment.selectedProject?.summary ?? ""
        }
    }

    private var identityCard: some View {
        SectionCard(
            title: "Project identity",
            subtitle: "The description shown on Overview is edited here, not on Overview itself."
        ) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                FormTextField(label: "Name", text: $projectName)
                FormTextField(label: "Description", text: $projectSummary, lineLimit: 2 ... 5)
                HStack {
                    Spacer()
                    Button("Save project details") {
                        environment.updateProject(name: projectName, summary: projectSummary)
                    }
                    .buttonStyle(.posPrimary)
                    .disabled(!hasIdentityEdits)
                }
            }
        }
    }

    private var inferenceCard: some View {
        SectionCard(
            title: "Recent inference",
            subtitle: "What was requested, which adapter answered, and what it reported back."
        ) {
            if environment.inferenceJobs.isEmpty {
                InlineEmptyText(text: "No inference requests recorded for this project.")
            } else {
                RowList(items: Array(environment.inferenceJobs.prefix(8))) { job in
                    RecordRow(
                        title: "\(job.purpose) · \(job.model)",
                        subtitle: usageDescription(for: job)
                    ) {
                        RowGlyph(
                            systemImage: symbol(for: job.status),
                            tone: tone(for: job.status),
                            isFilled: false
                        )
                    } trailing: {
                        StatusBadge(text: job.status.rawValue.capitalized, tone: .muted)
                    }
                }
            }
        }
    }

    private var ownershipCard: some View {
        SectionCard(title: "Ownership and recovery") {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                Text("Exports contain local project state, the exact source text, transcript distinctions, proposal and change history, provenance, relationships, and outcomes. Credentials and runtime caches are excluded.")
                    .font(TypeRole.body)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.step2) {
                    Button {
                        environment.exportSelectedProject()
                    } label: {
                        Label("Export project…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.posSecondary)

                    Button {
                        environment.restoreProject()
                    } label: {
                        Label("Restore as new project…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.posSecondary)
                }
                DisclosureNote(
                    text: "Restore validates the archive before creating a separate copy. Existing projects are never overwritten.",
                    systemImage: "checkmark.shield"
                )
            }
        }
    }

    private var deletionCard: some View {
        SectionCard(title: "Delete project") {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                Text("Deletion removes app-managed local content after cancelling active jobs. It does not remove exports, backups, local models, or data retained by an external provider.")
                    .font(TypeRole.body)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Permanently delete project") { confirmDelete = true }
                    .buttonStyle(.posDestructive)
            }
        } accessory: {
            StatusBadge(text: "Irreversible", symbol: "exclamationmark.triangle", tone: .warning)
        }
    }

    private func usageDescription(for job: InferenceJobRecord) -> String {
        var parts = [job.provider]
        if let route = job.configuredUpstreamRoute { parts.append("pinned \(route)") }
        if let actual = job.actualUpstreamProvider { parts.append("returned \(actual)") }
        if let cost = job.cost {
            let tokens = "\(job.inputTokens.map(String.init) ?? "?") in / \(job.outputTokens.map(String.init) ?? "?") out"
            parts.append("\(tokens) · \(NSDecimalNumber(decimal: cost).stringValue) \(job.currency ?? "")")
        } else {
            parts.append("cost unknown, not zero")
        }
        return parts.joined(separator: " · ")
    }

    private func symbol(for status: InferenceJobStatus) -> String {
        switch status {
        case .running: "circle.dotted"
        case .completed: "checkmark"
        case .failed: "exclamationmark.triangle"
        case .cancelled: "stop.circle"
        case .interrupted: "bolt.horizontal"
        }
    }

    private func tone(for status: InferenceJobStatus) -> StatusBadge.Tone {
        switch status {
        case .running: .accent
        case .completed: .success
        case .failed, .interrupted: .warning
        case .cancelled: .muted
        }
    }
}

/// Concise effects, the affected data, an export offer, and a typed
/// confirmation before the canonical action.
private struct DeleteProjectSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var isPresented: Bool

    @State private var confirmation = ""

    private var required: String { "DELETE \(environment.selectedProject?.name ?? "")" }

    var body: some View {
        SheetScaffold(
            title: "Permanently delete this project?",
            subtitle: "Deletion removes ProjectOS-managed content. It does not remove exports, backups, local models, or records retained by an external provider.",
            confirmTitle: "Delete local project",
            isConfirmEnabled: confirmation == required,
            isDestructive: true,
            confirm: {
                isPresented = false
                environment.deleteSelectedProject(typedConfirmation: confirmation)
            },
            cancel: { isPresented = false }
        ) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                Button {
                    environment.exportSelectedProject()
                } label: {
                    Label("Export first…", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.posSecondary)

                FormTextField(
                    label: "Type \(required) to confirm",
                    text: $confirmation,
                    prompt: required
                )
            }
        }
        .frame(width: 540)
    }
}
