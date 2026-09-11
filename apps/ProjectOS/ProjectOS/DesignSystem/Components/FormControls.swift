import SwiftUI

/// A labelled text field. The label sits above the control and doubles as the
/// accessibility name, so the placeholder never has to carry both jobs.
struct FormTextField: View {
    let label: String
    @Binding var text: String
    var prompt: String?
    var lineLimit: ClosedRange<Int>?
    var isSecure = false

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step1) {
            Text(label)
                .font(TypeRole.caption)
                .foregroundStyle(theme.muted)
            field
                .textFieldStyle(.plain)
                .font(TypeRole.body)
                .focused($isFocused)
                .padding(.horizontal, Spacing.step3)
                .padding(.vertical, Spacing.step2)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(
                            isFocused ? theme.focusIndicator : theme.essentialBoundary.opacity(0.5),
                            lineWidth: isFocused ? Stroke.loadBearing : Stroke.hairline
                        )
                }
                .animation(Motion.quick, value: isFocused)
                .accessibilityLabel(label)
        }
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField(prompt ?? label, text: $text)
        } else if let lineLimit {
            TextField(prompt ?? label, text: $text, axis: .vertical)
                .lineLimit(lineLimit)
        } else {
            TextField(prompt ?? label, text: $text)
        }
    }
}

/// A labelled multi-line editor for long text such as pasted source material.
struct FormTextEditor: View {
    let label: String
    @Binding var text: String
    var minHeight: CGFloat = 160
    var footnote: String?

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step1) {
            Text(label)
                .font(TypeRole.caption)
                .foregroundStyle(theme.muted)
            TextEditor(text: $text)
                .font(TypeRole.body)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .padding(Spacing.step2)
                .frame(minHeight: minHeight)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(
                            isFocused ? theme.focusIndicator : theme.essentialBoundary.opacity(0.5),
                            lineWidth: isFocused ? Stroke.loadBearing : Stroke.hairline
                        )
                }
                .animation(Motion.quick, value: isFocused)
                .accessibilityLabel(label)
            if let footnote {
                Text(footnote)
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            }
        }
    }
}

/// The shared sheet frame: title, explanation, content, and a cancel/confirm
/// pair. Confirmation sheets for consequential actions build on this so the
/// action hierarchy never varies between them.
struct SheetScaffold<Content: View>: View {
    let title: String
    var subtitle: String?
    var confirmTitle: String
    var isConfirmEnabled = true
    var isDestructive = false
    var confirm: () -> Void
    var cancel: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step4) {
            VStack(alignment: .leading, spacing: Spacing.step1) {
                Text(title)
                    .font(TypeRole.sectionTitle)
                    .foregroundStyle(theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
            HStack(spacing: Spacing.step2) {
                Spacer()
                Button("Cancel", action: cancel)
                    .buttonStyle(.posSecondary)
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, action: confirm)
                    .buttonStyle(isDestructive ? .posDestructive : .posPrimary)
                    .disabled(!isConfirmEnabled)
                    .keyboardShortcut(isDestructive ? .init("\r") : .defaultAction)
            }
        }
        .padding(Spacing.step5)
        .background(theme.surfaceRaised)
    }
}

/// A labelled control row for settings surfaces: native label / value / control.
struct SettingsRow<Control: View>: View {
    let label: String
    var help: String?
    @ViewBuilder var control: Control

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step1) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.step3) {
                Text(label)
                    .font(TypeRole.label)
                    .foregroundStyle(theme.text)
                Spacer(minLength: Spacing.step3)
                control
                    .frame(maxWidth: 300, alignment: .trailing)
            }
            if let help {
                Text(help)
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.step1)
    }
}
