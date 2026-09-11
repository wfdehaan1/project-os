import SwiftUI

/// Global settings: appearance and theme, then the inference provider.
///
/// Appearance and theme are independent, and neither changes typography,
/// spacing, behaviour, error meaning, or accessibility handling.
struct GlobalSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.step4) {
                appearanceCard
                InferenceSettingsSection()
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
