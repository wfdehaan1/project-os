import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var environment: AppEnvironment

    private var governing: [ArtifactRecord] { environment.artifacts.filter { $0.kind == .decision && $0.state == .current } }
    private var questions: [ArtifactRecord] { environment.artifacts.filter { $0.kind == .openQuestion && $0.state == .open } }
    private var tasks: [ArtifactRecord] { environment.artifacts.filter { $0.kind == .task && [.open, .inProgress, .blocked].contains($0.state) } }
    private var research: [ArtifactRecord] { environment.artifacts.filter { $0.kind == .research && $0.state != .removed }.prefix(5).map { $0 } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(environment.selectedProject?.name ?? "Overview").font(.largeTitle.bold())
                        Text(environment.selectedProject?.summary ?? "").foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Spacer()
                    Button("Record Return", systemImage: "clock.badge.checkmark") { environment.showOutcome = true }
                }

                if environment.artifacts.isEmpty {
                    ContentUnavailableView("No Accepted Project Knowledge", systemImage: "checkmark.seal", description: Text("Paste material, converse, and explicitly accept useful project updates. Overview stays available offline."))
                        .frame(maxWidth: .infinity).padding(.vertical, 32)
                }

                OverviewSection(title: "Governing Decisions", icon: "checkmark.seal", records: governing)
                HStack(alignment: .top, spacing: 16) {
                    OverviewSection(title: "Open Questions", icon: "questionmark.circle", records: questions)
                    OverviewSection(title: "Open Work", icon: "checklist", records: tasks)
                }
                OverviewSection(title: "Recent Research", icon: "book.pages", records: research)

                VStack(alignment: .leading, spacing: 10) {
                    HStack { Label("Changes Since Previous Visit", systemImage: "clock.arrow.circlepath").font(.headline); Spacer(); Button("Undo Latest") { environment.undoLatest() }.disabled(environment.changes.isEmpty) }
                    ForEach(environment.changesSincePreviousVisit.prefix(10)) { change in
                        HStack { Text("r\(change.revision)").font(.caption.monospaced()).foregroundStyle(.secondary); Text(change.summary); Spacer(); Text(change.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary) }
                    }
                    if environment.changesSincePreviousVisit.isEmpty { Text("No accepted changes since the previous visit.").foregroundStyle(.secondary) }
                }.card()

                VStack(alignment: .leading, spacing: 8) {
                    Label("Next Action", systemImage: "arrow.right.circle").font(.headline)
                    if let recommendation = environment.recommendation, !recommendation.isDismissed {
                        let stale = recommendation.originatingRevision != environment.selectedProject?.revision
                        Text(recommendation.text).fontWeight(.medium).textSelection(.enabled)
                        if let uncertainty = recommendation.uncertainty { Text("Uncertainty: \(uncertainty)").foregroundStyle(.secondary) }
                        Text(stale ? "Stale - accepted project state changed" : "Current at revision \(recommendation.originatingRevision)")
                            .font(.caption).foregroundStyle(stale ? .orange : .secondary)
                        ForEach(recommendation.supportingRecords) { support in
                            if let artifact = environment.artifacts.first(where: { $0.id == support.id }) {
                                Text("Supports: \(artifact.title) v\(support.version)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Button("Dismiss") { environment.dismissRecommendation() }
                    } else {
                        Text("Optional guidance is generated only when you ask and must cite accepted records. Opening Overview never sends project data.").foregroundStyle(.secondary)
                        Button("Suggest Next Action", systemImage: "sparkles") { environment.suggestNextAction() }
                            .disabled(environment.isGenerating || environment.artifacts.isEmpty)
                    }
                }.card()
            }.padding(24).frame(maxWidth: 1100, alignment: .leading)
        }
        .navigationTitle("Overview")
    }
}

private struct OverviewSection: View {
    let title: String
    let icon: String
    let records: [ArtifactRecord]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            if records.isEmpty { Text("None").foregroundStyle(.secondary) }
            ForEach(records) { record in
                VStack(alignment: .leading, spacing: 3) {
                    HStack { Text(record.title).fontWeight(.semibold); Spacer(); Text(record.state.rawValue).font(.caption).foregroundStyle(.secondary) }
                    Text(record.content).lineLimit(3).textSelection(.enabled)
                }.padding(.vertical, 4)
            }
        }.card().frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

extension View {
    func card() -> some View { padding(16).background(.background.secondary, in: RoundedRectangle(cornerRadius: 12)).overlay { RoundedRectangle(cornerRadius: 12).stroke(.separator) } }
}
