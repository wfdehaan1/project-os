import SwiftUI

struct ConversationView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showContext = true
    @State private var showProjectUpdates = true
    private let sideBySideRailMinimumWidth: CGFloat = 900

    var body: some View {
        GeometryReader { geometry in
            let listWidth = min(210, max(170, geometry.size.width * 0.22))
            let railWidth = min(340, max(280, geometry.size.width * 0.35))
            let showsSideBySideRail = showProjectUpdates && geometry.size.width >= sideBySideRailMinimumWidth
            let dividerWidth: CGFloat = showsSideBySideRail ? 2 : 1
            let contentWidth = geometry.size.width - listWidth - dividerWidth - (showsSideBySideRail ? railWidth : 0)

            ZStack(alignment: .topTrailing) {
                HStack(spacing: 0) {
                    ConversationListView()
                        .frame(width: listWidth)
                    Divider()
                    conversationContent
                        .frame(width: contentWidth)

                    if showsSideBySideRail {
                        Divider()
                        projectUpdatesRail
                            .frame(width: railWidth)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)

                if showProjectUpdates && !showsSideBySideRail {
                    projectUpdatesRail
                        .frame(width: min(340, max(280, geometry.size.width - 80)))
                        .shadow(color: .black.opacity(0.18), radius: 12, x: -4)
                }
            }
        }
    }

    private var conversationContent: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Conversation")
                        .font(.title2.bold())
                        .accessibilityIdentifier("conversation.workspace-heading")
                    Text(environment.generationStatus).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Paste Source", systemImage: "doc.on.clipboard") { environment.showAddSource = true }
                Button("Project Updates", systemImage: "tray.full") { showProjectUpdates.toggle() }
                    .accessibilityIdentifier("conversation.toggle-project-updates")
            }.padding()
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if environment.messages.isEmpty {
                            ContentUnavailableView("Start with your project", systemImage: "bubble.left", description: Text("Select context below, then ask a question. Sending never applies project updates."))
                        }
                        ForEach(environment.messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: environment.messages.count) { _, _ in if let id = environment.messages.last?.id { proxy.scrollTo(id) } }
            }

            Divider()
            DisclosureGroup(isExpanded: $showContext) {
                ContextPreviewView()
            } label: {
                Label("Context Preview", systemImage: "scope")
                    .font(.headline)
            }.padding(.horizontal).padding(.top, 10)

            TextEditor(text: $environment.draft)
                .frame(minHeight: 70, maxHeight: 130)
                .padding(8)
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator) }
                .padding(.horizontal)
                .onChange(of: environment.draft) { _, _ in environment.saveDraft() }
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.command) { environment.sendMessage(); return .handled }
                    return .ignored
                }
            HStack {
                Text("⌘↩ Send · AI proposes text only").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if environment.isGenerating { Button("Stop", systemImage: "stop.fill") { environment.stopGeneration() } }
                Button("Send", systemImage: "arrow.up.circle.fill") { environment.sendMessage() }.buttonStyle(.borderedProminent).disabled(environment.isGenerating || environment.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding()
        }
        .frame(minWidth: 360)
    }

    private var projectUpdatesRail: some View {
        ProposalRailView {
            showProjectUpdates = false
        }
    }
}

private struct ConversationListView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversations").font(.headline)
                Spacer()
                Button("New Conversation", systemImage: "plus") { environment.createConversation() }
                    .labelStyle(.iconOnly)
            }.padding()
            Divider()
            List(selection: Binding(get: { environment.selectedConversationID }, set: { id in if let id { environment.selectConversation(id) } })) {
                ForEach(environment.conversations) { conversation in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(conversation.title).lineLimit(2)
                        Text(conversation.updatedAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                    }.tag(conversation.id)
                }
            }
        }
    }
}

private struct MessageBubble: View {
    let message: MessageRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(message.role == .user ? "You" : "Assistant").font(.caption.bold())
                Text(message.completion.rawValue.capitalized).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(.quaternary, in: Capsule())
            }
            Text(message.text.isEmpty ? "No text received." : message.text).textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: 720, alignment: .leading)
        .background(message.role == .user ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

private struct ContextPreviewView: View {
    @EnvironmentObject private var environment: AppEnvironment
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(environment.contextPreview).font(.caption).textSelection(.enabled)
            Toggle("Project description", isOn: $environment.contextSelection.includeDescription)
            Stepper("Complete message range: last \(environment.contextSelection.messageCount)", value: $environment.contextSelection.messageCount, in: 0...100, step: 5)
            if !environment.sources.isEmpty {
                Menu("Choose sources (\(environment.contextSelection.sourceIDs.count))") {
                    ForEach(environment.sources) { source in
                        Toggle(source.label, isOn: Binding(get: { environment.contextSelection.sourceIDs.contains(source.id) }, set: { value in
                            if value { environment.contextSelection.sourceIDs.insert(source.id) } else { environment.contextSelection.sourceIDs.remove(source.id) }
                        }))
                    }
                }
            }
            if !environment.artifacts.filter({ $0.state != .removed && $0.state != .superseded }).isEmpty {
                Menu("Choose accepted records (\(environment.contextSelection.artifactIDs.count))") {
                    ForEach(environment.artifacts.filter { $0.state != .removed && $0.state != .superseded }) { artifact in
                        Toggle("\(artifact.kind.rawValue): \(artifact.title)", isOn: Binding(get: { environment.contextSelection.artifactIDs.contains(artifact.id) }, set: { value in
                            if value { environment.contextSelection.artifactIDs.insert(artifact.id) } else { environment.contextSelection.artifactIDs.remove(artifact.id) }
                        }))
                    }
                }
            }
        }.padding(.vertical, 8)
    }
}

private struct ProposalRailView: View {
    @EnvironmentObject private var environment: AppEnvironment
    let onClose: () -> Void
    var pending: [ProposalRecord] { environment.proposals.filter { $0.lifecycle == .pending || $0.lifecycle == .deferred } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Project Updates")
                        .font(.headline)
                        .accessibilityIdentifier("conversation.project-updates-heading")
                    Text("Pending, never automatic truth").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close Project Updates", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
            }
            Button("Suggest Project Updates", systemImage: "sparkles") { environment.suggestUpdates() }
                .buttonStyle(.borderedProminent).disabled(environment.isGenerating)
            Divider()
            if pending.isEmpty {
                ContentUnavailableView("No Pending Updates", systemImage: "tray", description: Text("Request suggestions from the currently disclosed context."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) { ForEach(pending) { ProposalCard(proposal: $0) } }
                }
            }
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.background.secondary)
    }
}

private struct ProposalCard: View {
    @EnvironmentObject private var environment: AppEnvironment
    let proposal: ProposalRecord
    @State private var title: String
    @State private var content: String
    @State private var confirmsDecision = false
    private var dependencies: [ProposalRecord] { environment.dependencyClosure(for: proposal) }
    private var requiresDecisionConfirmation: Bool {
        proposal.kind == .decision || dependencies.contains { $0.kind == .decision }
    }
    init(proposal: ProposalRecord) { self.proposal = proposal; _title = State(initialValue: proposal.title); _content = State(initialValue: proposal.content) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(proposal.kind.rawValue, systemImage: "square.and.pencil").font(.caption.bold())
            Text("\(proposal.operation.rawValue.capitalized) · \(proposal.dependencyIDs.count) dependencies · \(proposal.relationships.count) relationships").font(.caption2).foregroundStyle(.secondary)
            TextField("Title", text: $title).font(.headline)
            TextField("Content", text: $content, axis: .vertical).lineLimit(2...8)
            if let rationale = proposal.rationale { Text("Why: \(rationale)").font(.caption).foregroundStyle(.secondary) }
            if let state = proposal.proposedState { Text("Proposed state: \(state.rawValue)").font(.caption) }
            if let certainty = proposal.certainty { Text("Certainty: \(certainty)").font(.caption) }
            if let limitations = proposal.limitations { Text("Limitations: \(limitations)").font(.caption).foregroundStyle(.secondary) }
            if requiresDecisionConfirmation {
                Toggle("I confirm the decision(s) in this reviewed set", isOn: $confirmsDecision).font(.caption)
                Text("A matching quote proves only that the text exists; review the commitment and rationale before accepting.").font(.caption2).foregroundStyle(.secondary)
            }
            if !dependencies.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Accepted atomically with:").font(.caption.bold())
                    ForEach(dependencies) { dependency in
                        Text("• \(dependency.kind.rawValue): \(dependency.title) — \(dependency.content)").font(.caption)
                    }
                }.padding(6).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            }
            if proposal.operation == .supersede,
               let prior = proposal.targetID.flatMap({ id in environment.artifacts.first { $0.id == id } }) {
                Text("Replaces current decision: \(prior.title)\n\(prior.content)").font(.caption).padding(6).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            } else if let prior = environment.replacementCandidate(for: proposal) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("A current decision already governs this subject: \(prior.title)").font(.caption.bold())
                    Button("Mark as explicit replacement") { environment.markAsReplacement(proposal, prior: prior) }
                }.padding(6).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            }
            ForEach(proposal.evidence) { evidence in
                Button { environment.inspectEvidence(evidence) } label: {
                    Text("“\(evidence.quote)”\(evidence.aiAuthored ? " · AI-authored/unverified" : "")").font(.caption).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).padding(6).background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            }
            HStack {
                Button("Reject") { environment.setProposal(proposal, lifecycle: .rejected) }
                Button("Defer") { environment.setProposal(proposal, lifecycle: .deferred) }
                Spacer()
                Button(proposal.dependencyIDs.isEmpty ? "Accept" : "Accept reviewed set") { environment.accept(proposal, title: title, content: content) }.buttonStyle(.borderedProminent).disabled(requiresDecisionConfirmation && !confirmsDecision)
            }
        }.padding(12).background(.background, in: RoundedRectangle(cornerRadius: 10)).overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator) }
    }
}
