import SwiftUI

/// Conversation List, Transcript and Composer, and the Proposal Rail when the
/// width permits.
///
/// A narrow window turns the rail into an overlay pane rather than hiding it,
/// so pending proposal status and its approval effects never disappear.
struct ConversationView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var showContext = true
    @State private var showProjectUpdates = true

    /// Below this width the rail overlays the transcript instead of sitting
    /// beside it.
    private let sideBySideRailMinimumWidth: CGFloat = 900

    var body: some View {
        GeometryReader { geometry in
            let listWidth = min(220, max(180, geometry.size.width * 0.22))
            let railWidth = min(360, max(300, geometry.size.width * 0.35))
            let showsSideBySideRail = showProjectUpdates && geometry.size.width >= sideBySideRailMinimumWidth
            let dividerWidth: CGFloat = showsSideBySideRail ? 2 : 1
            let contentWidth = geometry.size.width - listWidth - dividerWidth - (showsSideBySideRail ? railWidth : 0)

            ZStack(alignment: .topTrailing) {
                HStack(spacing: 0) {
                    ConversationListView()
                        .frame(width: listWidth)
                    DecorativeDivider(axis: .vertical)
                    conversationContent
                        .frame(width: contentWidth)

                    if showsSideBySideRail {
                        DecorativeDivider(axis: .vertical)
                        projectUpdatesRail
                            .frame(width: railWidth)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)

                if showProjectUpdates && !showsSideBySideRail {
                    projectUpdatesRail
                        .frame(width: min(360, max(300, geometry.size.width - 80)))
                        .shadow(color: .black.opacity(0.18), radius: 12, x: -4)
                }
            }
        }
        .background(theme.canvas)
        .navigationTitle("Conversation")
    }

    private var projectUpdatesRail: some View {
        ProposalRailView { showProjectUpdates = false }
    }

    // MARK: - Transcript and composer

    private var conversationContent: some View {
        VStack(spacing: 0) {
            SurfaceHeader(
                title: "Conversation",
                titleIdentifier: "conversation.workspace-heading"
            ) {
                StatusMark(
                    text: environment.generationStatus,
                    symbol: environment.isGenerating ? "circle.dotted" : "checkmark.circle",
                    tone: environment.isGenerating ? .warning : .muted
                )
            } actions: {
                Button {
                    environment.showAddSource = true
                } label: {
                    Label("Paste source", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.posSecondary)

                Button {
                    showProjectUpdates.toggle()
                } label: {
                    Label("Project Updates", systemImage: "tray.full")
                }
                .buttonStyle(.posSecondary)
                .accessibilityIdentifier("conversation.toggle-project-updates")
            }
            DecorativeDivider()

            transcript

            DecorativeDivider()
            composer
        }
        .frame(minWidth: 360)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.step3) {
                    if environment.messages.isEmpty {
                        EmptyStateView(
                            title: "Start with your project",
                            message: "Choose the context below, then ask a question. Sending never applies project updates on its own.",
                            systemImage: "bubble.left.and.bubble.right"
                        )
                        .padding(.top, Spacing.step6)
                    }
                    ForEach(environment.messages) { message in
                        MessageBubble(message: message).id(message.id)
                    }
                }
                .padding(Spacing.step4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: environment.messages.count) { _, _ in
                if let id = environment.messages.last?.id { proxy.scrollTo(id) }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.step3) {
            ContextPreviewPanel(isExpanded: $showContext)

            TextEditor(text: $environment.draft)
                .font(TypeRole.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 72, maxHeight: 140)
                .padding(Spacing.step2)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(theme.essentialBoundary.opacity(0.5), lineWidth: Stroke.hairline)
                }
                .accessibilityLabel("Message")
                .onChange(of: environment.draft) { _, _ in environment.saveDraft() }
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.command) {
                        environment.sendMessage()
                        return .handled
                    }
                    return .ignored
                }

            HStack(spacing: Spacing.step2) {
                Text("⌘↩")
                    .font(TypeRole.code)
                    .foregroundStyle(theme.muted)
                Text("Send · the agent proposes text only")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
                Spacer(minLength: Spacing.step2)
                if environment.isGenerating {
                    Button {
                        environment.stopGeneration()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.posSecondary)
                }
                Button {
                    environment.sendMessage()
                } label: {
                    Label("Send", systemImage: "arrow.up")
                }
                .buttonStyle(.posPrimary)
                .disabled(
                    environment.isGenerating
                        || environment.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(Spacing.step4)
        .background(theme.canvas)
    }
}

/// Recency list of conversations with a clear selected treatment.
private struct ConversationListView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Conversations")
                    .font(TypeRole.heading)
                    .foregroundStyle(theme.text)
                Spacer()
                IconButton(systemImage: "plus", accessibilityLabel: "New conversation") {
                    environment.createConversation()
                }
            }
            .padding(Spacing.step3)

            DecorativeDivider()

            ScrollView {
                VStack(spacing: Spacing.step1) {
                    ForEach(environment.conversations) { conversation in
                        RecordRow(
                            title: conversation.title,
                            subtitle: conversation.updatedAt.formatted(date: .abbreviated, time: .shortened),
                            isSelected: environment.selectedConversationID == conversation.id,
                            action: { environment.selectConversation(conversation.id) }
                        )
                    }
                }
                .padding(Spacing.step2)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.sidebar)
    }
}

/// One turn. User, agent, incomplete, and failed turns are perceivably
/// distinct without relying on colour.
private struct MessageBubble: View {
    let message: MessageRecord

    @Environment(\.theme) private var theme

    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step2) {
            HStack(spacing: Spacing.step2) {
                Text(message.role.displayName)
                    .font(TypeRole.caption.weight(.semibold))
                    .foregroundStyle(theme.muted)
                if message.completion != .complete {
                    StatusBadge(
                        text: message.completion.displayName,
                        symbol: message.completion.symbolName,
                        tone: message.completion.tone
                    )
                }
                Spacer(minLength: 0)
                Text(message.createdAt, style: .time)
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            }
            messageText
                .font(TypeRole.body)
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.step3)
        .frame(maxWidth: 760, alignment: .leading)
        .background(isUser ? theme.selection : theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(
                    isUser ? theme.selectedBoundary.opacity(0.4) : theme.essentialBoundary.opacity(0.35),
                    lineWidth: Stroke.hairline
                )
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    /// Agent replies arrive as Markdown; the user's own words stay literal.
    @ViewBuilder private var messageText: some View {
        if message.text.isEmpty {
            Text("No text received.")
        } else if isUser {
            Text(message.text)
        } else {
            MarkdownText(message.text)
        }
    }
}

/// The bounded preflight panel: what would be sent, to which adapter and
/// model, and whether that leaves this Mac.
private struct ContextPreviewPanel: View {
    @Binding var isExpanded: Bool

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    private var acceptedRecords: [ArtifactRecord] {
        environment.artifacts.filter { $0.state != .removed && $0.state != .superseded }
    }

    var body: some View {
        SurfaceContainer(role: .tint, radius: Radius.md, padding: Spacing.step3) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                Button {
                    withAnimation(Motion.standard) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: Spacing.step2) {
                        Image(systemName: "scope").imageScale(.small)
                        Text("Context Preview")
                            .font(TypeRole.heading)
                            .accessibilityIdentifier("conversation.context-preview-heading")
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .imageScale(.small)
                            .foregroundStyle(theme.muted)
                    }
                    .foregroundStyle(theme.text)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Context Preview")

                DisclosureNote(
                    text: environment.providerDisclosure,
                    systemImage: environment.runsLocally ? "desktopcomputer" : "network"
                )

                if isExpanded {
                    VStack(alignment: .leading, spacing: Spacing.step2) {
                        Text(environment.contextPreview)
                            .font(TypeRole.caption)
                            .foregroundStyle(theme.muted)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        Toggle("Project description", isOn: $environment.contextSelection.includeDescription)
                            .toggleStyle(.checkbox)
                            .font(TypeRole.caption)

                        Stepper(
                            "Complete message range: last \(environment.contextSelection.messageCount)",
                            value: $environment.contextSelection.messageCount,
                            in: 0 ... 100,
                            step: 5
                        )
                        .font(TypeRole.caption)

                        HStack(spacing: Spacing.step2) {
                            if !environment.sources.isEmpty {
                                Menu("Sources (\(environment.contextSelection.sourceIDs.count))") {
                                    ForEach(environment.sources) { source in
                                        Toggle(source.label, isOn: binding(for: source))
                                    }
                                }
                                .frame(width: 180)
                            }
                            if !acceptedRecords.isEmpty {
                                Menu("Accepted records (\(environment.contextSelection.artifactIDs.count))") {
                                    ForEach(acceptedRecords) { artifact in
                                        Toggle("\(artifact.kind.rawValue): \(artifact.title)", isOn: binding(for: artifact))
                                    }
                                }
                                .frame(width: 220)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func binding(for source: SourceRecord) -> Binding<Bool> {
        Binding(
            get: { environment.contextSelection.sourceIDs.contains(source.id) },
            set: { included in
                if included {
                    environment.contextSelection.sourceIDs.insert(source.id)
                } else {
                    environment.contextSelection.sourceIDs.remove(source.id)
                }
            }
        )
    }

    private func binding(for artifact: ArtifactRecord) -> Binding<Bool> {
        Binding(
            get: { environment.contextSelection.artifactIDs.contains(artifact.id) },
            set: { included in
                if included {
                    environment.contextSelection.artifactIDs.insert(artifact.id)
                } else {
                    environment.contextSelection.artifactIDs.remove(artifact.id)
                }
            }
        )
    }
}
