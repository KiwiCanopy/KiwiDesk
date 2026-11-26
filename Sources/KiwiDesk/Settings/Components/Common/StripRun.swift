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

extension StripFollow where ID == String {
    /// A name-keyed strip's follow: the focused item while it is
    /// listed in `names`, else `fallback`; nil when neither is.
    static func named(
        focused: String?,
        else fallback: String?,
        in names: [String]
    ) -> Self? {
        let item =
            focused.flatMap { names.contains($0) ? $0 : nil }
            ?? fallback
        guard let item else { return nil }
        return names.firstIndex(of: item).map {
            Self(id: item, index: $0)
        }
    }
}

/// A strip's items along its run, answering Core's overflow
/// arithmetic (`ShelfOverflow`) for the fade and the focus follow.
struct StripRun {
    /// The items' own widths. A followed run passes them bare, since
    /// the anchor reads an item's width here; only an unfollowed run
    /// may add room to one.
    let lengths: [CGFloat]
    let gap: CGFloat
    /// The fade's depth: the items' drawn height.
    let depth: CGFloat
    /// Room inside the scroller past each end item.
    var endRoom: CGFloat = 0

    /// The run of items named `names` whose drawn sizes the strip
    /// measured into `sizes`: lengths bare, depth the tallest shown
    /// item's height. An item not yet measured takes no room.
    static func measured(
        _ names: [String],
        sizes: [String: CGSize],
        gap: CGFloat,
        endRoom: CGFloat
    ) -> StripRun {
        StripRun(
            lengths: names.map { sizes[$0]?.width ?? 0 },
            gap: gap,
            depth: names.compactMap { sizes[$0]?.height }.max() ?? 0,
            endRoom: endRoom
        )
    }

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
