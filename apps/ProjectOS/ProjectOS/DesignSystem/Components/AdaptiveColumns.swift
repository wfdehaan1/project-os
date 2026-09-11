import SwiftUI

/// Two columns side by side when the available width can give each a workable
/// measure, stacked when it cannot.
///
/// A custom `Layout` rather than `ViewThatFits`, because the cards here contain
/// flexible text: their ideal width is effectively unbounded, so a fit test
/// would always reject the horizontal arrangement. Deciding from the *proposed*
/// width instead is both correct and predictable.
///
/// This is what lets the Overview masthead grow and stack when Dutch expansion
/// or a larger system text size needs it to, rather than clipping to hold a
/// fixed height.
struct AdaptiveColumns: Layout {
    /// The width each column needs before a side-by-side arrangement is used.
    var minimumColumnWidth: CGFloat = 300
    /// A fixed width for the leading column, e.g. the Pile Cover. When `nil`
    /// the width is split by `leadingFraction`.
    var leadingWidth: CGFloat?
    /// The leading column's share of the available width when `leadingWidth`
    /// is not set.
    var leadingFraction: CGFloat = 0.5
    var spacing: CGFloat = Spacing.step4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else {
            return stackedSize(proposal: proposal, subviews: subviews)
        }
        let available = proposal.width ?? minimumColumnWidth * 2 + spacing
        guard let widths = columnWidths(for: available) else {
            return stackedSize(proposal: proposal, subviews: subviews)
        }
        let heights = zip(subviews, widths).map { subview, width in
            subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        return CGSize(width: available, height: heights.max() ?? 0)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2, let widths = columnWidths(for: bounds.width) else {
            placeStacked(in: bounds, subviews: subviews)
            return
        }
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }

    /// The two column widths, or `nil` when there is not enough room.
    private func columnWidths(for available: CGFloat) -> [CGFloat]? {
        let content = available - spacing
        guard content >= minimumColumnWidth * 2 else { return nil }
        let leading = leadingWidth.map { min($0, content - minimumColumnWidth) }
            ?? (content * leadingFraction)
        return [leading, content - leading]
    }

    private func stackedSize(proposal: ProposedViewSize, subviews: Subviews) -> CGSize {
        let width = proposal.width ?? 0
        let heights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        let gaps = spacing * CGFloat(max(0, subviews.count - 1))
        return CGSize(width: width, height: heights.reduce(0, +) + gaps)
    }

    private func placeStacked(in bounds: CGRect, subviews: Subviews) {
        var y = bounds.minY
        for subview in subviews {
            let height = subview.sizeThatFits(
                ProposedViewSize(width: bounds.width, height: nil)
            ).height
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                proposal: ProposedViewSize(width: bounds.width, height: height)
            )
            y += height + spacing
        }
    }
}
