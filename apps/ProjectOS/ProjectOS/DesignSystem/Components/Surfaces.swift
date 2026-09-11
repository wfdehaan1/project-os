import SwiftUI

/// Which tonal layer a container sits on. Hierarchy comes from layout,
/// typography, and tonal layering — not from dramatic elevation.
enum SurfaceRole {
    case canvas
    case surface
    case surfaceRaised
    case tint
    case sidebar

    func color(_ theme: Theme) -> Color {
        switch self {
        case .canvas: theme.canvas
        case .surface: theme.surface
        case .surfaceRaised: theme.surfaceRaised
        case .tint: theme.tint
        case .sidebar: theme.sidebar
        }
    }
}

/// How a container's boundary is drawn.
enum SurfaceBoundary {
    /// A boundary needed to perceive the container as a discrete object.
    case essential
    /// The container currently carries selection.
    case selected
    /// A pending or otherwise non-accepted layer. Dashed, so it can never be
    /// mistaken for accepted Canonical State.
    case pending
    /// No boundary at all.
    case none
}

/// The shared container behind cards, inspectors, rails, and panels.
///
/// Callers choose a role and a boundary; they never assemble their own
/// background, stroke, and radius. That keeps one visual contract across the
/// app and makes a spine change a single edit here.
struct SurfaceContainer<Content: View>: View {
    var role: SurfaceRole = .surface
    var boundary: SurfaceBoundary = .essential
    var radius: CGFloat = Radius.lg
    var padding: CGFloat? = Spacing.step4
    @ViewBuilder var content: Content

    @Environment(\.theme) private var theme

    var body: some View {
        content
            .padding(padding ?? 0)
            .background(role.color(theme), in: RoundedRectangle(cornerRadius: radius))
            .overlay { boundaryShape }
    }

    @ViewBuilder
    private var boundaryShape: some View {
        switch boundary {
        case .essential:
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(theme.essentialBoundary.opacity(0.45), lineWidth: Stroke.hairline)
        case .selected:
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(theme.selectedBoundary, lineWidth: Stroke.loadBearing)
        case .pending:
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(
                    theme.essentialBoundary,
                    style: StrokeStyle(lineWidth: Stroke.hairline, dash: [4, 3])
                )
        case .none:
            EmptyView()
        }
    }
}

extension View {
    /// Places a view on a themed surface. Prefer `SurfaceContainer` when the
    /// container is the point; use this when decorating an existing subtree.
    func posSurface(
        role: SurfaceRole = .surface,
        boundary: SurfaceBoundary = .essential,
        radius: CGFloat = Radius.lg,
        padding: CGFloat? = Spacing.step4
    ) -> some View {
        SurfaceContainer(role: role, boundary: boundary, radius: radius, padding: padding) { self }
    }
}

/// A hairline used only where removing it loses no component or state meaning.
struct DecorativeDivider: View {
    var axis: Axis = .horizontal

    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.decorativeDivider)
            .frame(
                width: axis == .vertical ? Stroke.hairline : nil,
                height: axis == .horizontal ? Stroke.hairline : nil
            )
            .accessibilityHidden(true)
    }
}
