import SwiftUI

/// KiwiHub's footer row geometry: the leading and trailing controls
/// at the row's edges and the middle view on the row's midline, so
/// the hints share one centre on every side; where the middle is too
/// wide for that, it moves toward the narrower control only as far
/// as it must. Expects exactly three subviews — leading, middle,
/// trailing.
struct JumpFooterMidline: Layout {
    var spacing: CGFloat

    /// The most a control may take before it truncates.
    static let controlShare: CGFloat = 0.5

    /// The room between the controls, each control with its gap; an
    /// absent control (zero wide) takes no gap.
    static func room(
        _ width: CGFloat,
        leading: CGFloat,
        trailing: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        let gaps = (leading > 0 ? spacing : 0) + (trailing > 0 ? spacing : 0)
        return max(width - leading - trailing - gaps, 0)
    }

    /// The middle's centre, from the row's leading edge: the midline,
    /// clamped so a middle `middle` wide stays clear of both controls.
    static func centre(
        _ width: CGFloat,
        leading: CGFloat,
        trailing: CGFloat,
        middle: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        let low = leading + (leading > 0 ? spacing : 0) + middle / 2
        let high =
            width - trailing - (trailing > 0 ? spacing : 0) - middle / 2
        guard low <= high else { return (low + high) / 2 }
        return min(max(width / 2, low), high)
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let width = proposal.width ?? ideal(subviews)
        let (lead, trail, middle) = sizes(width, subviews)
        let height = max(lead.height, trail.height, middle.height)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 3 else { return }
        let (lead, trail, middle) = sizes(bounds.width, subviews)
        let centre = Self.centre(
            bounds.width,
            leading: lead.width,
            trailing: trail.width,
            middle: middle.width,
            spacing: spacing
        )
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(lead)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + centre, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(middle)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: ProposedViewSize(trail)
        )
    }

    private func sizes(
        _ width: CGFloat,
        _ subviews: Subviews
    ) -> (CGSize, CGSize, CGSize) {
        let cap = ProposedViewSize(
            width: width * Self.controlShare,
            height: nil
        )
        let lead = subviews[0].sizeThatFits(cap)
        let trail = subviews[2].sizeThatFits(cap)
        let room = Self.room(
            width,
            leading: lead.width,
            trailing: trail.width,
            spacing: spacing
        )
        let middle = subviews[1].sizeThatFits(
            ProposedViewSize(width: room, height: nil)
        )
        return (
            lead, trail,
            CGSize(
                width: min(middle.width, room),
                height: middle.height
            )
        )
    }

    private func ideal(_ subviews: Subviews) -> CGFloat {
        subviews.map { $0.sizeThatFits(.unspecified).width }
            .reduce(0, +) + 2 * spacing
    }
}
