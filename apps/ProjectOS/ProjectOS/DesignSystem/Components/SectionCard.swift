import SwiftUI

/// A titled card: heading, optional sub-heading, content, and an optional
/// trailing accessory in the header.
///
/// `Current truth` and `Needs attention` on Overview, and every settings group,
/// are the same component with different content.
struct SectionCard<Content: View, Accessory: View>: View {
    let title: String
    var subtitle: String?
    var role: SurfaceRole = .surface
    @ViewBuilder var content: Content
    @ViewBuilder var accessory: Accessory

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceContainer(role: role, padding: Spacing.step4) {
            VStack(alignment: .leading, spacing: Spacing.step3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(TypeRole.heading)
                        .foregroundStyle(theme.text)
                    Spacer(minLength: Spacing.step3)
                    accessory
                }
                if let subtitle {
                    Text(subtitle)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension SectionCard where Accessory == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        role: SurfaceRole = .surface,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, subtitle: subtitle, role: role, content: content) { EmptyView() }
    }
}

/// The `View all …` row that closes a card. Separated from the card body by a
/// hairline that carries no meaning of its own.
struct CardFooterLink: View {
    let title: String
    var action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Spacing.step2) {
            DecorativeDivider()
            Button(action: action) {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: "chevron.right").imageScale(.small)
                }
                .font(TypeRole.label)
                .foregroundStyle(theme.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// A small labelled group inside a card, e.g. `Governing` above a list.
struct FieldGroupLabel: View {
    let text: String

    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .font(TypeRole.caption)
            .foregroundStyle(theme.muted)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Label and value on one line, for provenance and structured metadata.
struct MetaRow: View {
    let label: String
    let value: String
    var isMonospaced = false

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.step3) {
            Text(label)
                .font(TypeRole.caption)
                .foregroundStyle(theme.muted)
                .frame(width: 132, alignment: .leading)
            Text(value)
                .font(isMonospaced ? TypeRole.code : TypeRole.caption)
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
