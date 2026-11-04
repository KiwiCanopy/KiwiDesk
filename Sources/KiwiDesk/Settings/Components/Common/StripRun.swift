import KiwiDeskCore
import SwiftUI

/// Where a sideways strip stands, in points.
struct StripScroll: Equatable {
    var offset: CGFloat = 0
    var viewport: CGFloat = 0
}

/// The item a strip brings into view: its scroll id and run index.
struct StripFollow<ID: Hashable>: Equatable {
    let id: ID
    let index: Int
}

/// A strip's items along its run, answering Core's overflow
/// arithmetic (`ShelfOverflow`) for the fade and the focus follow.
struct StripRun {
    /// The items' own widths.
    let lengths: [CGFloat]
    let gap: CGFloat
    /// The fade's depth: the items' drawn height.
    let depth: CGFloat
    /// Room inside the scroller past each end item.
    var endRoom: CGFloat = 0

    /// Each item's run, the end room riding on the end items.
    private var runLengths: [CGFloat] {
        lengths.indices.map { index in
            lengths[index] + (index == 0 ? endRoom : 0)
                + (index == lengths.count - 1 ? endRoom : 0)
        }
    }

    var total: CGFloat {
        runLengths.reduce(0, +) + gap * CGFloat(max(lengths.count - 1, 0))
    }

    func fades(_ scroll: StripScroll) -> ShelfOverflow.Fades {
        ShelfOverflow.fades(
            lengths: runLengths,
            gap: gap,
            total: total,
            offset: scroll.offset,
            viewport: scroll.viewport,
            depth: depth
        )
    }

    /// A `scrollTo` anchor bringing the item at `index` clear of the
    /// fade through Core's follow, or nil where the strip need not
    /// move: an anchor's x places the item's leading edge at
    /// x · (viewport − width) in view.
    func followAnchor(index: Int, scroll: StripScroll) -> UnitPoint? {
        guard lengths.indices.contains(index) else { return nil }
        let target = ShelfOverflow.offset(
            current: scroll.offset,
            lengths: runLengths,
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
        let width = lengths[index]
        guard abs(target - scroll.offset) > 0.5, scroll.viewport > width
        else { return nil }
        let start =
            endRoom + lengths[..<index].reduce(0) { $0 + $1 + gap }
        let share = (start - target) / (scroll.viewport - width)
        return UnitPoint(x: min(max(share, 0), 1), y: 0.5)
    }
}
