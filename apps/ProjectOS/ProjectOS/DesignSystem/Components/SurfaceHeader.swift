import SwiftUI

/// The header every workspace destination starts with: an optional eyebrow, a
/// title, an optional status line, and trailing actions.
///
/// Having one header means a destination never invents its own title treatment,
/// and a change to the shell's rhythm is a single edit.
struct SurfaceHeader<Status: View, Actions: View>: View {
    var eyebrow: String?
    let title: String
    /// Optional accessibility identifier for the title, so a surface can be
    /// addressed by automation without a hidden marker element.
    var titleIdentifier: String?
    @ViewBuilder var status: Status
    @ViewBuilder var actions: Actions

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceHeaderLayout() {
            VStack(alignment: .leading, spacing: Spacing.step1) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(TypeRole.eyebrow)
                        .foregroundStyle(theme.muted)
                }
                Text(title)
                    .font(TypeRole.sectionTitle)
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(titleIdentifier ?? title)
                status
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions keep their intrinsic width so a control label never wraps
            // or truncates; the layout moves them to their own row instead.
            HStack(spacing: Spacing.step2) { actions }
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, Spacing.step5)
        .padding(.vertical, Spacing.step4)
    }
}

extension SurfaceHeader where Status == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        titleIdentifier: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            titleIdentifier: titleIdentifier,
            status: { EmptyView() },
            actions: actions
        )
    }
}

extension SurfaceHeader where Actions == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        titleIdentifier: String? = nil,
        @ViewBuilder status: () -> Status
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            titleIdentifier: titleIdentifier,
            status: status,
            actions: { EmptyView() }
        )
    }
}

extension SurfaceHeader where Status == EmptyView, Actions == EmptyView {
    init(eyebrow: String? = nil, title: String, titleIdentifier: String? = nil) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            titleIdentifier: titleIdentifier,
            status: { EmptyView() },
            actions: { EmptyView() }
        )
    }
}

/// The "saved on this Mac" line. Storage locality is a standing fact, so it is
/// stated plainly rather than announced as an event.
struct LocalStorageStatus: View {
    var detail: String?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.step2) {
            StatusMark(text: "Saved on this Mac", symbol: "checkmark.circle.fill", tone: .success)
            if let detail {
                Text("·")
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
                    .accessibilityHidden(true)
                Text(detail)
                    .font(TypeRole.caption)
                    .foregroundStyle(theme.muted)
            }
        }
        // A standing fact stays on one line; the surrounding column gives way
        // before this collapses into a character-per-line stack.
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A persistent, non-transient explanation attached to an action — used where a
/// control is disabled, or where the next action would leave the Mac.
struct DisclosureNote: View {
    let text: String
    var systemImage: String = "info.circle"

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.step2) {
            Image(systemName: systemImage)
                .imageScale(.small)
                .foregroundStyle(theme.muted)
                .accessibilityHidden(true)
            Text(text)
                .font(TypeRole.caption)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
