import SwiftUI

/// Plain explanation, one primary action, optionally one secondary action.
/// No illustration, sample data, or engagement copy.
struct EmptyStateView: View {
    struct Action {
        let title: String
        var systemImage: String?
        let handler: () -> Void

        init(title: String, systemImage: String? = nil, handler: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.handler = handler
        }
    }

    let title: String
    let message: String
    var systemImage: String?
    var primary: Action?
    var secondary: Action?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Spacing.step3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(theme.muted)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(TypeRole.heading)
                .foregroundStyle(theme.text)
            Text(message)
                .font(TypeRole.body)
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
            if primary != nil || secondary != nil {
                HStack(spacing: Spacing.step2) {
                    if let secondary {
                        button(secondary).buttonStyle(.posSecondary)
                    }
                    if let primary {
                        button(primary).buttonStyle(.posPrimary)
                    }
                }
                .padding(.top, Spacing.step1)
            }
        }
        .padding(Spacing.step6)
        .frame(maxWidth: .infinity)
    }

    private func button(_ action: Action) -> some View {
        Button(action: action.handler) {
            if let symbol = action.systemImage {
                Label(action.title, systemImage: symbol)
            } else {
                Text(action.title)
            }
        }
    }
}

/// The inline form of an empty state, for use inside a card where a full
/// centred block would be too heavy.
struct InlineEmptyText: View {
    let text: String

    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .font(TypeRole.body)
            .foregroundStyle(theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.step2)
    }
}
