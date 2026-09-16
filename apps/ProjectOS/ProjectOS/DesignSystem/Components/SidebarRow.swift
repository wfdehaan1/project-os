import SwiftUI

/// One sidebar destination. The active row uses a selection fill, a selected
/// boundary marker, and weight — never colour alone.
///
/// Shared by the project window and the Project Library so a navigation row
/// looks and behaves the same wherever the app navigates.
struct SidebarRow: View {
    let title: String
    let symbolName: String
    var badge: Int?
    let isSelected: Bool
    /// Stable identifier for automation, e.g. `sidebar.overview`.
    var identifier: String?
    let select: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: select) {
            HStack(spacing: Spacing.step2) {
                Rectangle()
                    .fill(isSelected ? theme.selectedBoundary : .clear)
                    .frame(width: 2.5)
                    .accessibilityHidden(true)
                Image(systemName: symbolName)
                    .imageScale(.small)
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? theme.accent : theme.muted)
                Text(title)
                    .font(isSelected ? TypeRole.label.weight(.semibold) : TypeRole.label)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer(minLength: Spacing.step2)
                if let badge {
                    Text("\(badge)")
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                        .monospacedDigit()
                }
            }
            .padding(.trailing, Spacing.step2)
            .padding(.vertical, Spacing.step2 - 1)
            .background(isSelected ? theme.selection : .clear, in: RoundedRectangle(cornerRadius: Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityIdentifier(identifier ?? title)
        .accessibilityLabel(title)
        // The count is a value, not part of the name, so the destination stays
        // addressable by its own title.
        .accessibilityValue(badge.map(String.init) ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
