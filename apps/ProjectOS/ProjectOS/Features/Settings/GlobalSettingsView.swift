import SwiftUI

/// Global settings: appearance and theme, then the inference provider.
///
/// Appearance and theme are independent, and neither changes typography,
/// spacing, behaviour, error meaning, or accessibility handling.
struct GlobalSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var openRouterKey = ""
    @State private var keyStatus = "Not inspected"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.step4) {
                appearanceCard
                providerCard
                ollamaCard
                openRouterCard
                HStack(spacing: Spacing.step2) {
                    Button("Test connectivity") { environment.testProvider() }
                        .buttonStyle(.posSecondary)
                    Spacer()
                    Button("Save settings") { environment.saveProviderSettings() }
                        .buttonStyle(.posPrimary)
                }
            }
            .padding(Spacing.step5)
        }
        .background(theme.canvas)
        .navigationTitle("Settings")
    }

    private var appearanceCard: some View {
        SectionCard(
            title: "Appearance",
            subtitle: "Appearance follows macOS until you choose otherwise. Theme is a separate, constrained identity."
        ) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                SettingsRow(label: "Appearance") {
                    Picker("Appearance", selection: $environment.appearance) {
                        ForEach(AppearancePreference.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                SettingsRow(
                    label: "Theme",
                    help: "Presets change identity colours only. System accessibility preferences always win."
                ) {
                    Picker("Theme", selection: $environment.themePreset) {
                        ForEach(ThemePreset.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                }
                ThemeSwatchRow(preset: environment.themePreset)
            }
        }
    }

    private var providerCard: some View {
        SectionCard(title: "Inference provider") {
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
                SettingsRow(label: "Documented context window (tokens)") {
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
                    TextField("", text: $environment.ollamaModel)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Installed local model")
                }
                DisclosureNote(
                    text: "Only loopback addresses and ports are accepted. ProjectOS does not install, start, stop, or download Ollama models.",
                    systemImage: "desktopcomputer"
                )
            }
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
}

/// A preview of the identity roles a preset changes, so the choice is visible
/// before it is applied everywhere.
private struct ThemeSwatchRow: View {
    let preset: ThemePreset

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.step2) {
            swatch(theme.accent, label: "Accent")
            swatch(theme.selection, label: "Selection")
            swatch(theme.tint, label: "Tint")
            swatch(theme.success, label: "Success")
            swatch(theme.warning, label: "Warning")
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.displayName) identity colours")
    }

    private func swatch(_ color: Color, label: String) -> some View {
        VStack(spacing: Spacing.step1) {
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(color)
                .frame(width: 44, height: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .strokeBorder(theme.essentialBoundary.opacity(0.4), lineWidth: Stroke.hairline)
                }
            Text(label)
                .font(TypeRole.caption)
                .foregroundStyle(theme.muted)
        }
    }
}
