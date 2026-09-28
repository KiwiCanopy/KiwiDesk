import SwiftUI

/// Lays a segmented strip's segments out at one width each, the way
/// a native segmented control does: its natural width is the widest
/// segment times the count, so a strip left at that width never
/// shortens its longest label. Given more room, the segments share
/// it equally, as they did in an `HStack` of flexible frames.
struct EqualSegmentsLayout: Layout {
    var spacing: CGFloat = 2

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let widest = ideals.map(\.width).max() ?? 0
        let gaps = spacing * CGFloat(subviews.count - 1)
        let natural = widest * CGFloat(subviews.count) + gaps
        return CGSize(
            width: proposal.width ?? natural,
            height: ideals.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let each = max(bounds.width - gaps, 0) / CGFloat(subviews.count)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(index) * (each + spacing),
                    y: bounds.minY
                ),
                proposal: ProposedViewSize(
                    width: each,
                    height: bounds.height
                )
            )
        }
    }
}
