import SwiftUI

/// The shared search field. Scope lives in the placeholder so the field never
/// needs a bespoke label per surface.
struct SearchField: View {
    let scope: String
    @Binding var text: String

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.step2) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(theme.muted)
                .accessibilityHidden(true)
            TextField(scope, text: $text)
                .textFieldStyle(.plain)
                .font(TypeRole.label)
                .focused($isFocused)
            if !text.isEmpty {
                IconButton(systemImage: "xmark.circle.fill", accessibilityLabel: "Clear search") {
                    text = ""
                }
            }
        }
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
        .accessibilityLabel(scope)
    }
}

/// A horizontal filter bar. Generic over anything identifiable so the ledger,
/// a conversation list, or any future surface can reuse it.
struct SegmentedFilterBar<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    var count: ((Item) -> Int?)?
    @Binding var selection: Item

    @Environment(\.theme) private var theme

    var body: some View {
        // Segments keep their intrinsic width and wrap to a second line when
        // the surface is narrow, so no filter is ever scrolled out of reach.
        FlowLayout(horizontalSpacing: Spacing.step1, verticalSpacing: Spacing.step1) {
            ForEach(items, id: \.self) { item in
                segment(item)
            }
        }
        .padding(Spacing.step1)
        .background(theme.tint, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(theme.essentialBoundary.opacity(0.35), lineWidth: Stroke.hairline)
        }
        .accessibilityElement(children: .contain)
    }

    private func segment(_ item: Item) -> some View {
        let isSelected = item == selection
        return Button {
            selection = item
        } label: {
            HStack(spacing: Spacing.step1) {
                Text(title(item))
                if let value = count?(item), value > 0 {
                    Text("\(value)")
                        .font(TypeRole.caption)
                        .foregroundStyle(isSelected ? theme.accentText.opacity(0.8) : theme.muted)
                }
            }
            .font(TypeRole.label)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isSelected ? theme.accentText : theme.text)
            .padding(.horizontal, Spacing.step3)
            .padding(.vertical, Spacing.step1 + 2)
            .background(isSelected ? theme.accent : .clear, in: RoundedRectangle(cornerRadius: Radius.sm))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
