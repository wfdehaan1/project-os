import SwiftUI

struct KnowledgeView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selectedKind: ArtifactKind?
    @State private var selectedID: UUID?
    @State private var showNewRecord = false

    private var filtered: [ArtifactRecord] {
        environment.artifacts.filter { ($0.state != .removed) && (selectedKind == nil || $0.kind == selectedKind) }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Knowledge").font(.title2.bold())
                    Spacer()
                    Picker("Kind", selection: $selectedKind) {
                        Text("All").tag(nil as ArtifactKind?)
                        ForEach(ArtifactKind.allCases) { Text($0.rawValue).tag($0 as ArtifactKind?) }
                    }.frame(width: 180)
                    Button("New Record", systemImage: "plus") { showNewRecord = true }
                }.padding()
                Divider()
                List(filtered, selection: $selectedID) { artifact in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack { Text(artifact.title).fontWeight(.medium); Spacer(); Text(artifact.state.rawValue).font(.caption).foregroundStyle(.secondary) }
                        Text(artifact.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                    }.tag(artifact.id)
                }
            }.frame(minWidth: 300)

            if let artifact = environment.artifacts.first(where: { $0.id == selectedID }) {
                ArtifactInspector(artifact: artifact)
            } else {
                ContentUnavailableView("Select a Record", systemImage: "sidebar.right", description: Text("Inspect content, rationale, evidence, versions, and history."))
            }
        }
        .sheet(isPresented: $showNewRecord) { NewArtifactSheet(isPresented: $showNewRecord) }
    }
}

private struct NewArtifactSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var isPresented: Bool
    @State private var kind: ArtifactKind = .topic
    @State private var title = ""
    @State private var content = ""
    @State private var rationale = ""
    @State private var subject = ""

    var body: some View {
        Form {
            Text("New Project Record").font(.title2.bold())
            Picker("Kind", selection: $kind) { ForEach(ArtifactKind.allCases) { Text($0.rawValue).tag($0) } }
            TextField("Title", text: $title)
            TextField("Content", text: $content, axis: .vertical).lineLimit(4...8)
            TextField("Rationale (optional)", text: $rationale, axis: .vertical).lineLimit(2...4)
            if kind == .decision { TextField("Decision subject", text: $subject) }
            Text("This is a user-authored correction. It enters accepted state with history and does not pretend to come from AI.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Save") { environment.createArtifact(kind: kind, title: title, content: content, rationale: rationale, decisionSubject: subject); isPresented = false }
                    .buttonStyle(.borderedProminent).disabled(title.isEmpty || content.isEmpty)
            }
        }.padding(24).frame(width: 520)
    }
}

private struct ArtifactInspector: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State var artifact: ArtifactRecord
    @State private var relationType = "supports"
    @State private var relationTarget: UUID?

    private var allowedStates: [ArtifactState] {
        switch artifact.kind {
        case .topic, .research: [.current, .removed]
        case .decision: [.current, .superseded, .removed]
        case .openQuestion: [.open, .resolved, .dismissed, .removed]
        case .task: [.open, .inProgress, .blocked, .done, .removed]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(artifact.kind.rawValue).font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    Text("v\(artifact.version)").font(.caption)
                    Picker("Status", selection: $artifact.state) { ForEach(allowedStates, id: \.self) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 130)
                }
                TextField("Title", text: $artifact.title).font(.title2.bold())
                TextEditor(text: $artifact.content).frame(minHeight: 130).overlay { RoundedRectangle(cornerRadius: 6).stroke(.separator) }
                if let rationale = artifact.rationale { LabeledContent("Rationale") { Text(rationale).textSelection(.enabled) } }
                if let subject = artifact.decisionSubject { LabeledContent("Decision subject") { Text(subject).textSelection(.enabled) } }
                if let certainty = artifact.certainty { LabeledContent("Certainty") { Text(certainty).textSelection(.enabled) } }
                if let limitations = artifact.limitations { LabeledContent("Limitations") { Text(limitations).textSelection(.enabled) } }
                Divider()
                Text("Evidence").font(.headline)
                if artifact.evidence.isEmpty { Text("No cited evidence. User-authored correction.").foregroundStyle(.secondary) }
                ForEach(artifact.evidence) { evidence in
                    Button { environment.inspectEvidence(evidence) } label: { VStack(alignment: .leading, spacing: 4) {
                        Text(evidence.quote).textSelection(.enabled)
                        Text("\(evidence.sourceType) · version \(evidence.version)\(evidence.aiAuthored ? " · AI-authored/unverified" : "")").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
                Divider()
                Text("Relationships").font(.headline)
                ForEach(artifact.relationships) { relation in
                    let targetTitle = environment.artifacts.first(where: { $0.id == relation.targetArtifactID })?.title ?? "Missing target"
                    Text("\(relation.type) → \(targetTitle)").font(.caption)
                }
                HStack {
                    Picker("Type", selection: $relationType) { ForEach(["supports", "concerns", "advances", "blocks", "supersedes"], id: \.self) { Text($0).tag($0) } }.frame(width: 150)
                    Picker("Target", selection: $relationTarget) {
                        Text("Choose record").tag(nil as UUID?)
                        ForEach(environment.artifacts.filter { $0.id != artifact.id && $0.state != .removed }) { Text($0.title).tag($0.id as UUID?) }
                    }
                    Button("Link") { if let target = relationTarget { environment.linkArtifact(artifact, to: target, type: relationType) } }.disabled(relationTarget == nil)
                }
                HStack {
                    Button("Remove", role: .destructive) { environment.removeArtifact(artifact) }
                    Spacer()
                    Button("Save Correction") { environment.saveArtifact(artifact, summary: "Corrected \(artifact.kind.rawValue): \(artifact.title)") }.buttonStyle(.borderedProminent)
                }
                Divider()
                Text("History").font(.headline)
                ForEach(environment.changes.filter { $0.beforeArtifact?.id == artifact.id || $0.afterArtifact?.id == artifact.id }) { change in Text("r\(change.revision) · \(change.summary)").font(.caption).textSelection(.enabled) }
            }.padding(24)
        }.frame(minWidth: 380)
    }
}
