import SwiftUI

/// A Bars preview title held to the App Bar's fixed slot: as wide as
/// the title reads, never past `slot`, a longer one cut with "…" —
/// the live item's label (#2545, #2643). `.frame(maxWidth:)` alone
/// stretches a short title to the slot whenever the row offers room.
/// A nil `slot` (a bar with no title cap) passes the offer through.
struct BarStripSlotTitle: Layout {
    let slot: CGFloat?

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let title = subviews.first else { return .zero }
        let width =
            slot.map { min(proposal.width ?? $0, $0) } ?? proposal.width
        return title.sizeThatFits(
            ProposedViewSize(width: width, height: proposal.height)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(
            at: bounds.origin,
            proposal: ProposedViewSize(
                width: bounds.width,
                height: bounds.height
            )
        )
    }
}
