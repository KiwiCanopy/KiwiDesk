import CoreGraphics

/// Where the bars sit along the shelf's edge (#1517) — the ONE
/// placement rule: the live bars take their segments from it and
/// the Settings preview and alignment note ask it, so no picture
/// states a placement the engine does not make (gui.md, #702).
///
/// A lone bar spans the edge and sits where `alignment` puts it.
/// Two bars take opposite ends in `order`, each hugging its own
/// end; the edge splits by `share` only once BOTH need more than
/// their share, and a bar that needs less gives the rest back.
public struct ShelfArrangement: Equatable, Sendable {
    /// One bar's segment: `offset` and `length` along the edge
    /// from its start (left on a horizontal edge, top on a
    /// vertical one), and where the bar's run sits inside it.
    public struct Slot: Equatable, Sendable {
        public var offset: CGFloat
        public var length: CGFloat
        public var alignment: KiwiShelf.Alignment

        /// The segment as a rect within `strip`, in the strip's
        /// own (top-left origin) coordinates.
        public func rect(in strip: CGRect, horizontal: Bool) -> CGRect {
            horizontal
                ? CGRect(
                    x: strip.minX + offset,
                    y: strip.minY,
                    width: length,
                    height: strip.height
                )
                : CGRect(
                    x: strip.minX,
                    y: strip.minY + offset,
                    width: strip.width,
                    height: length
                )
        }
    }

    public var space: Slot?
    public var app: Slot?

    public init(space: Slot? = nil, app: Slot? = nil) {
        self.space = space
        self.app = app
    }

    /// Places the shown bars along an edge `length` long. A nil
    /// need means that bar does not show; a need is the bar's
    /// natural run length, plate included.
    public static func arrange(
        length: CGFloat,
        spaceNeed: CGFloat?,
        appNeed: CGFloat?,
        shelf: KiwiShelf
    ) -> ShelfArrangement {
        let whole = max(length, 0)
        switch (spaceNeed, appNeed) {
        case (nil, nil):
            return ShelfArrangement()
        case (.some, nil):
            return ShelfArrangement(space: lone(whole, shelf))
        case (nil, .some):
            return ShelfArrangement(app: lone(whole, shelf))
        case (.some(let spaceNeed), .some(let appNeed)):
            let spacesFirst = shelf.order == .spacesFirst
            let gutter = max(shelf.itemGap, 0)
            let room = max(whole - gutter, 0)
            let firstNeed = spacesFirst ? spaceNeed : appNeed
            let secondNeed = spacesFirst ? appNeed : spaceNeed
            let spaceShare = shelf.resolvedShare / 100
            let firstShare = spacesFirst ? spaceShare : 1 - spaceShare
            let first = firstLength(
                room: room,
                firstNeed: firstNeed,
                secondNeed: secondNeed,
                firstShare: firstShare
            )
            let leading = Slot(offset: 0, length: first, alignment: .start)
            let trailing = Slot(
                offset: first + gutter,
                length: room - first,
                alignment: .end
            )
            return spacesFirst
                ? ShelfArrangement(space: leading, app: trailing)
                : ShelfArrangement(space: trailing, app: leading)
        }
    }

    /// Whether the Space Bar sits somewhere else once an App Bar
    /// joins it — the trade-off the alignment picker states — and
    /// which end it moves to. Nil where it stays put.
    public static func spaceBarMoves(
        shelf: KiwiShelf
    ) -> KiwiShelf.Alignment? {
        let joined: KiwiShelf.Alignment =
            shelf.order == .spacesFirst ? .start : .end
        return shelf.alignment == joined ? nil : joined
    }

    private static func lone(
        _ length: CGFloat,
        _ shelf: KiwiShelf
    ) -> Slot {
        Slot(offset: 0, length: length, alignment: shelf.alignment)
    }

    /// The first bar's length: each bar gets what it needs while
    /// both fit; past that the bar needing less than its share
    /// keeps its need and the other takes the rest, and only when
    /// both overflow does `share` decide.
    private static func firstLength(
        room: CGFloat,
        firstNeed: CGFloat,
        secondNeed: CGFloat,
        firstShare: CGFloat
    ) -> CGFloat {
        let firstShareLength = room * firstShare
        if firstNeed + secondNeed <= room {
            return min(max(firstShareLength, firstNeed), room - secondNeed)
        }
        if firstNeed <= firstShareLength { return firstNeed }
        if secondNeed <= room - firstShareLength {
            return room - secondNeed
        }
        return firstShareLength
    }
}
