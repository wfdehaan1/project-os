import SwiftUI

/// One reusable button with the variants named by the design spine.
///
/// Primary accent is reserved for the most consequential *available* action on
/// a surface. A disabled button keeps a legible label; the reason belongs beside
/// it as persistent text, never as a tooltip alone.
enum ButtonProminence {
    case primary
    case secondary
    case ghost
    case destructive
}

struct POSButtonStyle: ButtonStyle {
    let prominence: ButtonProminence

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeRole.label)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .foregroundStyle(foreground)
            .padding(.horizontal, prominence == .ghost ? Spacing.step2 : Spacing.step3)
            .padding(.vertical, Spacing.step2)
            .frame(minHeight: 24)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(border, lineWidth: Stroke.hairline)
            }
            .opacity(isEnabled ? 1 : 0.55)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .contentShape(RoundedRectangle(cornerRadius: Radius.md))
            .animation(Motion.quick, value: configuration.isPressed)
    }

    private var foreground: Color {
        switch prominence {
        case .primary: theme.accentText
        case .secondary, .ghost: theme.text
        case .destructive: theme.destructive
        }
    }

    private var background: Color {
        switch prominence {
        case .primary: theme.accent
        case .secondary: theme.surface
        case .ghost: .clear
        case .destructive: theme.surface
        }
    }

    private var border: Color {
        switch prominence {
        case .primary: .clear
        case .secondary: theme.essentialBoundary
        case .ghost: .clear
        case .destructive: theme.destructive.opacity(0.55)
        }
    }
}

extension ButtonStyle where Self == POSButtonStyle {
    /// The most consequential available action on a surface.
    static var posPrimary: POSButtonStyle { POSButtonStyle(prominence: .primary) }
    /// A normal action with a perceivable boundary.
    static var posSecondary: POSButtonStyle { POSButtonStyle(prominence: .secondary) }
    /// A low-emphasis action inside dense chrome.
    static var posGhost: POSButtonStyle { POSButtonStyle(prominence: .ghost) }
    /// Native macOS destructive semantics; never themed.
    static var posDestructive: POSButtonStyle { POSButtonStyle(prominence: .destructive) }
}

/// A compact icon-only control for chrome such as pane close buttons.
struct IconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.callout)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.muted)
        .accessibilityLabel(accessibilityLabel)
    }
}

#if DEBUG
#Preview {
    ThemedPreview {
        VStack(alignment: .leading, spacing: Spacing.step3) {
            Button("Continue work") {}.buttonStyle(.posPrimary)
            Button("Inspect context") {}.buttonStyle(.posSecondary)
            Button("Why this?") {}.buttonStyle(.posGhost)
            Button("Delete project") {}.buttonStyle(.posDestructive)
            Button("Unavailable offline") {}.buttonStyle(.posPrimary).disabled(true)
        }
        .padding(Spacing.step5)
    }
}
#endif
