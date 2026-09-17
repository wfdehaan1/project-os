import SwiftUI

struct CodexExperimentView: View {
    @StateObject private var model: CodexExperimentModel
    @State private var showContext = true
    private let fixture: Bool

    init() {
        fixture = ProcessInfo.processInfo.arguments.contains("--codex-experiment-fixture")
        let override = ProcessInfo.processInfo.environment["PROJECTOS_CODEX_EXPERIMENT_STATE"]
        let url = override.map { URL(fileURLWithPath: $0) } ?? (fixture ? FileManager.default.temporaryDirectory.appending(path: "CodexExperimentFixture-\(UUID())/state.json") : nil)
        _model = StateObject(wrappedValue: CodexExperimentModel(stateURL: url))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            connection
            Divider()
            HStack(alignment: .top, spacing: 0) {
                conversation
                Divider()
                contextPanel.frame(width: 285)
            }
            Divider()
            composer
        }
        .frame(minWidth: 900, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if fixture { await model.connect(using: CodexExperimentFixture(), resume: false) }
        }
        .onDisappear { model.disconnect() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "bubble.left.and.text.bubble.right").foregroundStyle(.tint)
                Text("Codex Experiment").font(.title2.bold()).accessibilityIdentifier("codex.heading")
                Spacer()
                Text("Synthetic project only").font(.caption).padding(6).background(.quaternary, in: Capsule())
            }
            Text("Native chat · External Codex execution · ChatGPT account · No project updates applied")
                .font(.caption).foregroundStyle(.secondary)
            if fixture { Text("DETERMINISTIC UI FIXTURE — no live Codex connection").font(.caption.bold()).foregroundStyle(.orange) }
        }.padding()
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.connected {
                HStack {
                    SecureField("Helper pairing code (PORT:TOKEN)", text: $model.pairing)
                        .textFieldStyle(.roundedBorder).accessibilityIdentifier("codex.pairing")
                    Button(model.state.sessionID == nil ? "Connect" : "Resume") { Task { await model.connect(resume: model.state.sessionID != nil) } }
                        .disabled(model.busy || model.pairing.isEmpty).accessibilityIdentifier("codex.connect")
                    if model.state.sessionID != nil {
                        Button("Start fresh") {
                            Task { if model.pairing.isEmpty { await model.fresh() } else { await model.connect(resume: false) } }
                        }
                        .disabled(model.busy || (model.pairing.isEmpty && !model.canStartFresh))
                        .help("Archives the current transcript locally and creates a new agent session.")
                        .accessibilityIdentifier("codex.fresh")
                    }
                }
            } else {
                HStack {
                    Picker("Model", selection: $model.selectedModel) {
                        ForEach(model.models, id: \.id) { item in Text(item.name).tag(item.id) }
                    }.frame(maxWidth: 420).disabled(model.busy).accessibilityIdentifier("codex.model")
                    Spacer()
                    Button("Start fresh") { Task { await model.fresh() } }
                        .disabled(model.busy).accessibilityIdentifier("codex.fresh")
                        .help("Archives the current transcript locally and creates a new agent session.")
                    Button("Disconnect") { model.disconnect() }.accessibilityIdentifier("codex.disconnect")
                }
            }
            Text(model.status).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("codex.status")
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled).accessibilityIdentifier("codex.error") }
        }.padding(.horizontal).padding(.vertical, 10)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if model.state.messages.isEmpty {
                        ContentUnavailableView("Chat with Codex", systemImage: "bubble.left", description: Text("Discuss a synthetic garden office, use Codex's built-in web search, and validate a pending project proposal."))
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(model.state.messages) { message in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(message.role == "user" ? "You" : "Codex").font(.headline)
                                if message.addedContext { Text("+ synthetic context").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                if message.status != "complete" { Text(message.status).font(.caption).foregroundStyle(.secondary) }
                            }
                            Text(message.text.isEmpty ? "Working…" : .init(message.text))
                                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier(message.role == "assistant" ? "codex.assistant-message" : "codex.user-message")
                        }
                        .padding(12)
                        .background(message.role == "user" ? Color.accentColor.opacity(0.07) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                        .id(message.id)
                    }
                    ForEach(model.permissions) { permission in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(permission.title, systemImage: "hand.raised").font(.headline)
                            Text("This turn only. File and command operations are rejected by the helper.").font(.caption)
                            HStack {
                                ForEach(permission.options) { option in
                                    Button(option.name) { Task { await model.respond(permission, optionID: option.id) } }
                                }
                            }
                        }.padding().background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding()
            }
            .onChange(of: model.state.messages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private var contextPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Context Preview").font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Added this turn").font(.subheadline.bold())
                    Toggle("Synthetic project context", isOn: $model.includeContext).disabled(model.busy)
                        .accessibilityIdentifier("codex.include-context")
                    Text(model.includeContext ? CodexExperimentModel.syntheticContext : "Only your next message will be added.")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Retained agent history").font(.subheadline.bold())
                    Text(model.retainedContextDescription).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("codex.retained-context")
                }
                Divider()
                Label("Codex tools", systemImage: "globe").font(.subheadline.bold())
                Text("Built-in web search. No SearXNG or ProjectOS research tools are forwarded. Citations are external links, not retained page snapshots.").font(.caption).foregroundStyle(.secondary)
                Text("The helper runs outside the app sandbox. Its restrictions do not prove isolation from all Codex configuration or native tools.").font(.caption).foregroundStyle(.secondary)
                if !model.activities.isEmpty {
                    Text("Agent activity").font(.subheadline.bold())
                    ForEach(model.activities) { activity in
                        VStack(alignment: .leading, spacing: 3) {
                            Label(activity.title, systemImage: activity.kind == "search" ? "magnifyingglass" : "gearshape.2")
                            Text(activity.status).foregroundStyle(.secondary)
                        }.font(.caption).accessibilityIdentifier("codex.activity")
                    }
                }
                if !model.pendingProposals.isEmpty {
                    Divider()
                    Label("Validated · Pending only", systemImage: "checkmark.shield").font(.subheadline.bold()).accessibilityIdentifier("codex.proposal-validated")
                    ForEach(model.pendingProposals) { proposal in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(proposal.title).font(.subheadline.bold())
                            Text(proposal.content).font(.caption)
                            ForEach(proposal.evidence) { evidence in Text("“\(evidence.quote)”").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    Text("Production schema and exact evidence checked. This experiment cannot accept or apply proposals.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding()
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Message Codex", text: $model.draft, axis: .vertical)
                .lineLimit(2...5).textFieldStyle(.roundedBorder).disabled(model.busy)
                .accessibilityIdentifier("codex.draft")
            HStack {
                Button("Suggest project update") { Task { await model.send(proposal: true) } }
                    .disabled(!model.connected || model.busy || !model.includeContext).accessibilityIdentifier("codex.propose")
                Spacer()
                if model.busy {
                    ProgressView().controlSize(.small)
                    Button("Stop") { Task { await model.stop() } }.accessibilityIdentifier("codex.stop")
                } else {
                    Button("Send") { Task { await model.send() } }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
                        .disabled(!model.connected || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.selectedModel.isEmpty)
                        .accessibilityIdentifier("codex.send")
                }
            }
        }.padding()
    }
}
