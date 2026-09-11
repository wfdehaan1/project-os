import SwiftUI

/// The 4 / 8 / 12 / 16 / 24 / 32 rhythm from the design spine.
///
/// Related content stays tight; major surfaces and semantic shifts take the
/// larger steps. Views never hard-code a number that has a token.
enum Spacing {
    static let step1: CGFloat = 4
    static let step2: CGFloat = 8
    static let step3: CGFloat = 12
    static let step4: CGFloat = 16
    static let step5: CGFloat = 24
    static let step6: CGFloat = 32

    /// Icon-only sidebar width.
    static let sidebarCollapsed: CGFloat = 56
    /// Tested starting width for English, not a fixed minimum.
    static let sidebarDefault: CGFloat = 184
    /// Tested starting width for Dutch expansion.
    static let sidebarDutch: CGFloat = 216
    /// Reference minimum for the Overview masthead row; never a maximum.
    static let mastheadMinimumHeight: CGFloat = 120
    /// Comfortable measure for long-form reading surfaces.
    static let readableWidth: CGFloat = 1080
}

/// Corner radii. Gently rounded and tool-like; `full` is only for status
/// badges and compact counts.
enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
    static let window: CGFloat = 14
}

/// The three purposeful motion constants. A transition must clarify location,
/// causality, state change, or truthful progress — nothing else animates.
enum Motion {
    static let quickDuration: Double = 0.14
    static let standardDuration: Double = 0.22
    static let deliberateDuration: Double = 0.30

    /// Local control feedback.
    static let quick = Animation.easeOut(duration: quickDuration)
    /// Navigation and pane continuity.
    static let standard = Animation.easeInOut(duration: standardDuration)
    /// Deliberate state transitions such as an atomic accepted-set reveal.
    static let deliberate = Animation.easeInOut(duration: deliberateDuration)

    /// Reduce Motion replaces spatial movement with immediate replacement, or
    /// with a short opacity-only transition when continuity still helps.
    static func respectingReduceMotion(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: quickDuration) : animation
    }
}

/// Semantic type roles. ProjectOS inherits native macOS typography and San
/// Francisco, so every role is a system text style and scales with the user's
/// enlargement settings.
enum TypeRole {
    /// Project identity and empty-state orientation. Used sparingly.
    static let title = Font.largeTitle.weight(.semibold)
    /// Secondary identity, e.g. a surface title inside the workspace.
    static let sectionTitle = Font.title2.weight(.semibold)
    /// Surface and inspector headings.
    static let heading = Font.headline
    /// Explanations and accepted content.
    static let body = Font.body
    /// Controls and structured metadata.
    static let label = Font.callout
    /// Provenance and secondary state.
    static let caption = Font.caption
    /// Small uppercase eyebrow above a title.
    static let eyebrow = Font.caption.weight(.semibold)
    /// Shortcuts, identifiers, manifest values, technical excerpts only.
    static let code = Font.system(.caption, design: .monospaced)
}

/// Hairline and boundary widths.
enum Stroke {
    static let hairline: CGFloat = 1
    /// Boundaries that must stay perceivable, e.g. selection and focus.
    static let loadBearing: CGFloat = 1.5
}
