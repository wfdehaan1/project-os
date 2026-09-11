import SwiftUI

struct ProjectWorkspaceView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        NavigationSplitView {
            List(selection: $environment.section) {
                Section {
                    ForEach(WorkspaceSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.icon).tag(section)
                    }
                }
                Section("Project") {
                    Button("All Projects", systemImage: "chevron.left") { environment.closeProject() }
                }
            }
            .navigationTitle(environment.selectedProject?.name ?? "Project")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            switch environment.section {
            case .overview: OverviewView()
            case .conversation: ConversationView()
            case .knowledge: KnowledgeView()
            case .settings: ProjectSettingsView()
            }
        }
        .sheet(isPresented: $environment.showAddSource) { AddSourceSheet() }
        .sheet(isPresented: $environment.showOutcome) { OutcomeFormView() }
        .sheet(item: $environment.evidenceInspection) { EvidenceInspectorSheet(evidence: $0) }
    }
}

private struct EvidenceInspectorSheet: View {
    let evidence: EvidenceInspection
    @Environment(\.dismiss) private var dismiss

    private var highlightedText: AttributedString {
        var text = AttributedString(evidence.fullText)
        if let range = text.range(of: evidence.quote) {
            text[range].backgroundColor = .yellow.opacity(0.45)
            text[range].foregroundColor = .primary
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(evidence.label).font(.title2.bold())
                    Text("Retained version \(evidence.version)\(evidence.aiAuthored ? " · AI-authored/unverified" : "")").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Divider()
            ScrollView { Text(highlightedText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(24).frame(minWidth: 620, minHeight: 420)
    }
}
