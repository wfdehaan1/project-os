import SwiftUI

/// The inference provider settings, shared by the Settings window and the
/// in-project Settings page.
///
/// Everything here is global and applies to every project. Nothing contacts a
/// provider until the person explicitly tests, looks up models, or generates.
struct InferenceSettingsSection: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var openRouterKey = ""
    @State private var keyStatus = "Not inspected"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step4) {
            providerCard
            ollamaCard
            openRouterCard
            webResearchCard
            HStack(spacing: Spacing.step2) {
                Button("Test connectivity") { environment.testProvider() }
                    .buttonStyle(.posSecondary)
                Spacer()
                Button("Save settings") { environment.saveProviderSettings() }
                    .buttonStyle(.posPrimary)
            }
        }
    }

    private var providerCard: some View {
        SectionCard(title: "Inference provider", subtitle: "Shared by every project.") {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                SettingsRow(label: "Provider") {
                    Picker("Provider", selection: $environment.provider) {
                        ForEach(ProviderChoice.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                }
                SettingsRow(label: "Readiness") {
                    StatusBadge(
                        text: environment.providerReadiness.displayName,
                        symbol: environment.providerReadiness.symbolName,
                        tone: environment.providerReadiness.tone
                    )
                }
                SettingsRow(
                    label: "Documented context window (tokens)",
                    help: "Ollama is asked to run with exactly this window (num_ctx). Larger windows use more memory."
                ) {
                    TextField("", text: $environment.contextWindowTokens)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Documented context window in tokens")
                }
                SettingsRow(label: "Maximum output tokens") {
                    TextField("", text: $environment.maximumOutputTokens)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Maximum output tokens")
                }
                DisclosureNote(
                    text: "Connected means transport worked. Only a recorded live capability and quality walkthrough can mark a model qualified.",
                    systemImage: "checkmark.seal"
                )
            }
        }
    }

    private var ollamaCard: some View {
        SectionCard(title: "Ollama", subtitle: "Runs on this Mac.") {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                SettingsRow(label: "Loopback URL") {
                    TextField("", text: $environment.ollamaURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Ollama loopback URL")
                }
                SettingsRow(label: "Installed local model") {
                    ollamaModelControl
                }
                HStack(spacing: Spacing.step2) {
                    Text(environment.ollamaModelLookupStatus)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                    Spacer()
                    Button("Find installed models") { environment.findInstalledOllamaModels() }
                        .buttonStyle(.posSecondary)
                        .disabled(environment.isLookingUpOllamaModels)
                }
                DisclosureNote(
                    text: "Only loopback addresses and ports are accepted, and cloud-backed models are never listed. ProjectOS does not install, start, stop, or download Ollama models.",
                    systemImage: "desktopcomputer"
                )
            }
        }
    }

    /// A picker once models have been looked up; free text before that, so a
    /// known model name can still be entered without contacting Ollama.
    @ViewBuilder
    private var ollamaModelControl: some View {
        let installed = environment.installedOllamaModels
        if installed.isEmpty {
            TextField("", text: $environment.ollamaModel)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Installed local model")
        } else {
            Picker("Installed local model", selection: $environment.ollamaModel) {
                if !installed.contains(environment.ollamaModel) {
                    Text(environment.ollamaModel.isEmpty ? "Choose a model" : "\(environment.ollamaModel) (not installed)")
                        .tag(environment.ollamaModel)
                }
                ForEach(installed, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
        }
    }

    private var openRouterCard: some View {
        SectionCard(title: "OpenRouter", subtitle: "External, and billed separately.") {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                SettingsRow(label: "Stable model ID") {
                    TextField("", text: $environment.openRouterModel)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Stable model ID")
                }
                SettingsRow(label: "Pinned upstream provider route") {
                    TextField("", text: $environment.openRouterRoute)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Pinned upstream provider route")
                }
                SettingsRow(label: "Approved test spending ceiling (USD)") {
                    TextField("", text: $environment.approvedSpendingCeilingUSD)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Approved test spending ceiling in US dollars")
                }
                SettingsRow(label: "API key", help: "Stored in the macOS Keychain, never in project data or exports.") {
                    SecureField("", text: $openRouterKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("OpenRouter API key")
                }
                HStack(spacing: Spacing.step2) {
                    Text(keyStatus)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                    Spacer()
                    Button("Remove key") {
                        environment.removeOpenRouterKey()
                        openRouterKey = ""
                        keyStatus = "Removed from Keychain"
                    }
                    .buttonStyle(.posDestructive)
                    Button("Save key") {
                        Task {
                            keyStatus = await environment.saveOpenRouterKey(openRouterKey)
                                ? "Saved in Keychain"
                                : "Could not save key"
                        }
                    }
                    .buttonStyle(.posSecondary)
                }
                DisclosureNote(
                    text: "No automatic retry, model fallback, or hidden provider switch. Usage and cost are shown only when the provider returns them.",
                    systemImage: "network"
                )
            }
        }
    }

    /// Web research is off in ordinary conversations and on in research ones,
    /// and each conversation can decide for itself. This is only where the
    /// search service lives.
    private var webResearchCard: some View {
        SectionCard(title: "Web research", subtitle: "SearXNG on this Mac, used by conversations with web research on.") {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                SettingsRow(label: "SearXNG loopback URL") {
                    TextField("", text: $environment.searxngURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("SearXNG loopback URL")
                }
                HStack(spacing: Spacing.step2) {
                    Text(environment.searxngStatus)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                    Spacer()
                    Button("Test SearXNG") { environment.testSearXNG() }
                        .buttonStyle(.posSecondary)
                        .disabled(environment.isTestingSearXNG)
                }
                DisclosureNote(
                    text: "Start SearXNG yourself, for example with: docker run -d -p 8888:8080 searxng/searxng. Then add json to search.formats in its settings.yml and restart it, or it will refuse to answer ProjectOS.",
                    systemImage: "terminal"
                )
                DisclosureNote(
                    text: "SearXNG has no index of its own: it passes your search terms to the engines it is configured for. Pages are downloaded from their own sites over HTTPS, without cookies. Only loopback addresses are accepted here.",
                    systemImage: "globe"
                )
            }
        }
    }
}
