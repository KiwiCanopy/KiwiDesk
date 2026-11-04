import KiwiDeskCore
import SwiftUI

/// Where a sideways strip stands, in points.
struct StripScroll: Equatable {
    var offset: CGFloat = 0
    var viewport: CGFloat = 0
}

/// A strip's items along its run, answering Core's overflow
/// arithmetic (`ShelfOverflow`) for the fade and the focus follow.
/// `inset` is room before the first item, carried in `lengths[0]`.
struct StripRun {
    let lengths: [CGFloat]
    let gap: CGFloat
    /// The fade's depth: the items' drawn height.
    let depth: CGFloat
    var inset: CGFloat = 0

    var total: CGFloat {
        lengths.reduce(0, +) + gap * CGFloat(max(lengths.count - 1, 0))
    }

    func fades(_ scroll: StripScroll) -> ShelfOverflow.Fades {
        ShelfOverflow.fades(
            lengths: lengths,
            gap: gap,
            total: total,
            offset: scroll.offset,
            viewport: scroll.viewport,
            depth: depth
        )
    }

    /// Where Core's follow puts the strip for the item at `index`,
    /// clear of the fade.
    func followOffset(index: Int, scroll: StripScroll) -> CGFloat {
        ShelfOverflow.offset(
            current: scroll.offset,
            lengths: lengths,
            gap: gap,
            total: total,
            activeIndex: index,
            viewport: scroll.viewport,
            margin: ShelfOverflow.followMargin(
                gap: gap,
                depth: depth,
                viewport: scroll.viewport
            )
        )
    }

    /// `followOffset` as a `scrollTo` anchor on an item `width` wide,
    /// or nil where the strip need not move: an anchor's x places the
    /// item's leading edge at x · (viewport − width) in view.
    func followAnchor(
        index: Int,
        width: CGFloat,
        scroll: StripScroll
    ) -> UnitPoint? {
        let target = followOffset(index: index, scroll: scroll)
        guard abs(target - scroll.offset) > 0.5, scroll.viewport > width
        else { return nil }
        let start =
            index == 0
            ? inset : lengths[..<index].reduce(0) { $0 + $1 + gap }
        let share = (start - target) / (scroll.viewport - width)
        return UnitPoint(x: min(max(share, 0), 1), y: 0.5)
    }
}
