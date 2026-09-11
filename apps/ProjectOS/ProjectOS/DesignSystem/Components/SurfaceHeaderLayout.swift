import SwiftUI

/// Places a title column and an actions group on one row, and moves the actions
/// onto their own row when the title would be squeezed below a readable width.
///
/// The actions always get their intrinsic width — a control label that wrapped
/// or truncated would hide what the control does. The title gives way first,
/// and when it has nothing left to give, the header grows a second row instead
/// of hyphenating a heading.
struct SurfaceHeaderLayout: Layout {
    /// The narrowest measure a title column may be squeezed to before the
    /// actions move to their own row.
    var minimumTitleWidth: CGFloat = 200
    var horizontalSpacing: CGFloat = Spacing.step4
    var verticalSpacing: CGFloat = Spacing.step3

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? minimumTitleWidth
        let actionsWidth = intrinsicActionsWidth(subviews)

        if let titleWidth = sideBySideTitleWidth(available: width, actionsWidth: actionsWidth) {
            let titleHeight = height(of: subviews[0], width: titleWidth)
            let actionsHeight = height(of: subviews[1], width: actionsWidth)
            return CGSize(width: width, height: max(titleHeight, actionsHeight))
        }

        let titleHeight = height(of: subviews[0], width: width)
        let actionsHeight = height(of: subviews[1], width: max(width, actionsWidth))
        return CGSize(width: width, height: titleHeight + verticalSpacing + actionsHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        let actionsWidth = intrinsicActionsWidth(subviews)

        if let titleWidth = sideBySideTitleWidth(available: bounds.width, actionsWidth: actionsWidth) {
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                proposal: ProposedViewSize(width: titleWidth, height: nil)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.maxX - actionsWidth, y: bounds.minY),
                proposal: ProposedViewSize(width: actionsWidth, height: nil)
            )
            return
        }

        let titleHeight = height(of: subviews[0], width: bounds.width)
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: ProposedViewSize(width: bounds.width, height: nil)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + titleHeight + verticalSpacing),
            proposal: ProposedViewSize(width: max(bounds.width, actionsWidth), height: nil)
        )
    }

    /// The title's width when both fit on one row, or `nil` when they do not.
    private func sideBySideTitleWidth(available: CGFloat, actionsWidth: CGFloat) -> CGFloat? {
        guard actionsWidth > 0 else { return available }
        let remaining = available - actionsWidth - horizontalSpacing
        return remaining >= minimumTitleWidth ? remaining : nil
    }

    private func intrinsicActionsWidth(_ subviews: Subviews) -> CGFloat {
        subviews[1].sizeThatFits(.unspecified).width
    }

    private func height(of subview: LayoutSubview, width: CGFloat) -> CGFloat {
        subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
    }
}
