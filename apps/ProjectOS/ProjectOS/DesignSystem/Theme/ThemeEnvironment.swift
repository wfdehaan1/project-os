import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeResolver.resolve(
        preset: .default,
        colorScheme: .light,
        increasedContrast: false
    )
}

extension EnvironmentValues {
    /// The resolved semantic palette for the current preset, appearance, and
    /// contrast setting. Every component reads colour from here.
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// Resolves and injects the active theme, and applies the explicit appearance
/// preference. Wrap the root of a window in this once.
///
/// It observes `colorScheme` and `colorSchemeContrast` so a change to the macOS
/// appearance or to Increase Contrast recolours without any view knowing how.
struct ThemedRoot<Content: View>: View {
    let preset: ThemePreset
    let appearance: AppearancePreference
    @ViewBuilder var content: Content

    var body: some View {
        ThemeResolutionLayer(preset: preset) { content }
            .preferredColorScheme(appearance.colorScheme)
    }
}

/// Split from `ThemedRoot` so the environment reads happen *below* the
/// `preferredColorScheme` call and therefore see the effective appearance.
private struct ThemeResolutionLayer<Content: View>: View {
    let preset: ThemePreset
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var theme: Theme {
        ThemeResolver.resolve(
            preset: preset,
            colorScheme: colorScheme,
            increasedContrast: contrast == .increased
        )
    }

    var body: some View {
        content
            .environment(\.theme, theme)
            .tint(theme.accent)
            .foregroundStyle(theme.text)
            .background(theme.canvas)
    }
}

#if DEBUG
/// Wraps a preview in a resolved theme so components render in isolation.
struct ThemedPreview<Content: View>: View {
    var preset: ThemePreset = .default
    @ViewBuilder var content: Content

    var body: some View {
        ThemeResolutionLayer(preset: preset) { content }
    }
}
#endif
