import SwiftUI

/// Compact text plus a shape, so pending, accepted, blocked, superseded,
/// offline, and current stay distinguishable without colour. A badge never
/// relies on a decorative divider as its boundary.
struct StatusBadge: View {
    enum Tone {
        case neutral
        case accent
        case success
        case warning
        case muted
    }

    let text: String
    var symbol: String?
    var tone: Tone = .neutral

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.step1) {
            if let symbol {
                Image(systemName: symbol).imageScale(.small)
            }
            Text(text)
        }
        .font(TypeRole.caption)
        .foregroundStyle(foreground)
        .padding(.horizontal, Spacing.step2)
        .padding(.vertical, 3)
        .background(background, in: Capsule())
        .overlay { Capsule().strokeBorder(border, lineWidth: Stroke.hairline) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: theme.text
        case .accent: theme.accent
        case .success: theme.success
        case .warning: theme.warning
        case .muted: theme.muted
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: theme.surface
        case .accent: theme.selection
        case .success, .warning: theme.surface
        case .muted: theme.surface
        }
    }

    private var border: Color {
        tone == .accent ? theme.selectedBoundary : theme.essentialBoundary
    }
}

/// A status expressed as a leading mark plus text, for use inside dense rows
/// where a full badge would crowd the line. The mark carries a distinct shape
/// per tone so colour is never the only cue.
struct StatusMark: View {
    let text: String
    let symbol: String
    var tone: StatusBadge.Tone = .neutral

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.step2) {
            Image(systemName: symbol)
                .imageScale(.small)
                .foregroundStyle(color)
            Text(text)
                .font(TypeRole.caption)
                .foregroundStyle(theme.muted)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    private var color: Color {
        switch tone {
        case .neutral: theme.text
        case .accent: theme.accent
        case .success: theme.success
        case .warning: theme.warning
        case .muted: theme.muted
        }
    }
}

#if DEBUG
#Preview {
    ThemedPreview {
        VStack(alignment: .leading, spacing: Spacing.step3) {
            StatusBadge(text: "Governing", symbol: "checkmark.seal.fill", tone: .accent)
            StatusBadge(text: "Needs recap", symbol: "arrow.clockwise", tone: .warning)
            StatusBadge(text: "Offline", symbol: "wifi.slash", tone: .muted)
            StatusMark(text: "Superseded", symbol: "circle.dashed", tone: .muted)
        }
        .padding(Spacing.step5)
    }
}
#endif
