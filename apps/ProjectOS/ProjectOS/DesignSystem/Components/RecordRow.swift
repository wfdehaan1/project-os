import SwiftUI

/// The shared list row: an optional leading mark, a title, optional secondary
/// text, and an optional trailing slot.
///
/// Overview's `Current truth` list, the state ledger, the change log, and the
/// source list are all this row with different slots filled. Row *shape* is
/// decided here; what goes in the slots is the caller's business.
struct RecordRow<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    var isSelected = false
    var showsDisclosure = false
    var action: (() -> Void)?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @Environment(\.theme) private var theme

    var body: some View {
        if let action {
            Button(action: action) { rowBody }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
        } else {
            rowBody
        }
    }

    private var accessibilityLabel: String {
        subtitle.map { "\(title). \($0)" } ?? title
    }

    private var rowBody: some View {
        HStack(alignment: .center, spacing: Spacing.step3) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TypeRole.body)
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: Spacing.step3)
            trailing
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .foregroundStyle(theme.muted)
            }
        }
        .padding(.horizontal, Spacing.step3)
        .padding(.vertical, Spacing.step2 + 2)
        .background(isSelected ? theme.selection : .clear, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(theme.selectedBoundary, lineWidth: Stroke.loadBearing)
            }
        }
        .contentShape(Rectangle())
    }
}

extension RecordRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        showsDisclosure: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            showsDisclosure: showsDisclosure,
            action: action,
            leading: leading,
            trailing: { EmptyView() }
        )
    }
}

extension RecordRow where Leading == EmptyView, Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        showsDisclosure: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            showsDisclosure: showsDisclosure,
            action: action,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}

/// The circular type mark that leads a row. Shape and symbol carry the type;
/// colour only reinforces it.
struct RowGlyph: View {
    let systemImage: String
    var tone: StatusBadge.Tone = .accent
    var isFilled = true

    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isFilled ? onColor : color)
            .frame(width: 26, height: 26)
            .background(isFilled ? color : .clear, in: RoundedRectangle(cornerRadius: Radius.sm))
            .overlay {
                if !isFilled {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .strokeBorder(color, lineWidth: Stroke.hairline)
                }
            }
            .accessibilityHidden(true)
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

    private var onColor: Color {
        tone == .accent ? theme.accentText : theme.surface
    }
}

/// A vertical stack of rows separated by hairlines, with no divider after the
/// last row.
struct RowList<Item: Identifiable, RowContent: View>: View {
    let items: [Item]
    @ViewBuilder var row: (Item) -> RowContent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item)
                if index < items.count - 1 {
                    DecorativeDivider().padding(.leading, Spacing.step3)
                }
            }
        }
    }
}
