import SwiftUI

/// The resolved semantic colour roles a component may use.
///
/// A component asks for a role — never for a preset. `ThemeResolver` decides
/// which preset, appearance, and contrast variant backs each role, so adding a
/// preset or honouring a new accessibility preference never touches a view.
struct Theme: Equatable {
    let preset: ThemePreset

    // Structural surfaces and readable content.
    let canvas: Color
    let sidebar: Color
    let surface: Color
    let surfaceRaised: Color
    let text: Color
    let muted: Color

    /// Optional hairlines only. Never the sole cue identifying a control,
    /// selection, record, or state.
    let decorativeDivider: Color

    // Constrained project identity and emphasis.
    let accent: Color
    let accentText: Color
    let selection: Color
    let tint: Color

    /// Named feedback states; never the only state cue. Destructive and error
    /// meaning stays native macOS semantic colour.
    let success: Color
    let warning: Color

    // Load-bearing boundaries.
    let essentialBoundary: Color
    let selectedBoundary: Color
    let focusIndicator: Color

    // Project Map.
    let graphEdge: Color
    let graphNodeBoundary: Color

    // Pile Cover marks.
    let pileDecision: Color
    let pileDecisionSuperseded: Color
    let pileQuestion: Color
    let pileProposal: Color
    let pileGround: Color

    /// Destructive and error meaning is never themed.
    var destructive: Color { .red }
}

/// Explicit appearance choice. Appearance and theme are independent.
enum AppearancePreference: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Follow macOS"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// `nil` means "inherit from macOS".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Turns a preset plus the live system appearance and contrast settings into a
/// `Theme`. Accessibility preference handling overrides theme identity.
enum ThemeResolver {
    static func resolve(
        preset: ThemePreset,
        colorScheme: ColorScheme,
        increasedContrast: Bool
    ) -> Theme {
        let definition = preset.definition
        let isDark = colorScheme == .dark
        let palette = isDark ? definition.dark : definition.light
        let overlay: ThemeContrastOverlay? = increasedContrast
            ? (isDark ? definition.darkContrast : definition.lightContrast)
            : nil

        return Theme(
            preset: preset,
            canvas: Color(hex: palette.canvas),
            sidebar: Color(hex: palette.sidebar),
            surface: Color(hex: palette.surface),
            surfaceRaised: Color(hex: palette.surfaceRaised),
            text: Color(hex: palette.text),
            muted: Color(hex: palette.muted),
            decorativeDivider: Color(hex: palette.decorativeDivider),
            accent: Color(hex: palette.accent),
            accentText: Color(hex: palette.accentText),
            selection: Color(hex: palette.selection),
            tint: Color(hex: palette.tint),
            success: Color(hex: palette.success),
            warning: Color(hex: palette.warning),
            essentialBoundary: Color(hex: overlay?.essentialBoundary ?? palette.essentialBoundary),
            selectedBoundary: Color(hex: overlay?.selectedBoundary ?? palette.selectedBoundary),
            focusIndicator: Color(hex: overlay?.focusIndicator ?? palette.focusIndicator),
            graphEdge: Color(hex: overlay?.graphEdge ?? palette.graphEdge),
            graphNodeBoundary: Color(hex: overlay?.graphNodeBoundary ?? palette.graphNodeBoundary),
            pileDecision: Color(hex: overlay?.pileDecision ?? palette.pileDecision),
            pileDecisionSuperseded: Color(hex: overlay?.pileDecisionSuperseded ?? palette.pileDecisionSuperseded),
            pileQuestion: Color(hex: overlay?.pileQuestion ?? palette.pileQuestion),
            pileProposal: Color(hex: overlay?.pileProposal ?? palette.pileProposal),
            pileGround: Color(hex: overlay?.pileGround ?? palette.pileGround)
        )
    }
}

extension Color {
    /// Parses the `#RRGGBB` form used by the design spine's colour contract.
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt64(digits, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
