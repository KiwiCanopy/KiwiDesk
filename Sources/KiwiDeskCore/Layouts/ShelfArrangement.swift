import CoreGraphics

/// Where the bars sit along the shelf's edge (#1517) — the ONE
/// placement rule: the live bars take their segments from it and
/// the Settings preview and alignment note ask it, so no picture
/// states a placement the engine does not make (gui.md, #702).
///
/// A lone bar spans the edge and sits where `alignment` puts it.
/// Two bars are one joined plate of two sections in `order`,
/// placed as a unit by `alignment`: each section is its need
/// while both fit; once the shelf is full the Space section
/// shrinks, never below the Space Bar minimum, and the App
/// section takes the rest and scrolls.
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
    /// Set only while both bars need more than the edge holds.
    public var divider: Divider?

    /// The middle of the gutter between two bars, along the edge;
    /// nil unless both show.
    public var dividerMiddle: CGFloat? {
        guard let space, let app else { return nil }
        let (first, second) =
            space.offset < app.offset
            ? (space, app) : (app, space)
        return (first.offset + first.length + second.offset) / 2
    }

    public init(
        space: Slot? = nil,
        app: Slot? = nil,
        divider: Divider? = nil
    ) {
        self.space = space
        self.app = app
        self.divider = divider
    }

    /// Places the shown bars along an edge `length` long. A nil
    /// need means that bar does not show; a need is the bar's
    /// natural run length, plate included. `spaceFloor` is the
    /// Space section's hard floor (`minimumRange`), below which no
    /// minimum may shrink it.
    public static func arrange(
        length: CGFloat,
        spaceNeed: CGFloat?,
        appNeed: CGFloat?,
        spaceFloor: CGFloat,
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
            let gutter = max(shelf.itemGap, 0)
            let room = max(whole - gutter, 0)
            let bounds = minimumRange(
                hardFloor: spaceFloor,
                spaceNeed: spaceNeed,
                room: room
            )
            let minimum = min(
                max(room * shelf.resolvedMinimum / 100, bounds.lowerBound),
                bounds.upperBound
            )
            let spaceLength = spaceSection(
                room: room,
                spaceNeed: spaceNeed,
                appNeed: appNeed,
                floor: minimum
            )
            let appLength = min(appNeed, room - spaceLength)
            let unit = spaceLength + gutter + appLength
            let start = lead(unit, in: whole, shelf.alignment)
            let spacesFirst = shelf.order == .spacesFirst
            let firstLength = spacesFirst ? spaceLength : appLength
            let first = Slot(
                offset: start,
                length: firstLength,
                alignment: .end
            )
            let second = Slot(
                offset: start + firstLength + gutter,
                length: spacesFirst ? appLength : spaceLength,
                alignment: .start
            )
            let divider =
                spaceNeed + appNeed > room
                ? Divider(
                    room: room,
                    spaceLength: spaceLength,
                    minimumLength: minimum,
                    bounds: bounds,
                    spacesFirst: spacesFirst
                )
                : nil
            return spacesFirst
                ? ShelfArrangement(space: first, app: second, divider: divider)
                : ShelfArrangement(space: second, app: first, divider: divider)
        }
    }

    /// Whether the Space section moves once an App Bar joins it —
    /// the trade-off the alignment picker states — as the one
    /// alignment that would hold it still: the plate anchored at
    /// the Space section's own end. Nil where it stays put.
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

    /// Where the Space section's minimum may lie, in points: from
    /// the hard floor — the active item and a fade each side, so
    /// the Space the user is on is never cut — to the Space Bar's
    /// natural length, both within `room`. The one clamp `arrange`
    /// and the divider drag share.
    public static func minimumRange(
        hardFloor: CGFloat,
        spaceNeed: CGFloat,
        room: CGFloat
    ) -> ClosedRange<CGFloat> {
        let ceiling = max(min(spaceNeed, room), 0)
        return min(max(hardFloor, 0), ceiling)...ceiling
    }

    /// The Space section's hard floor for an active item
    /// `activeExtent` long on a shelf `thickness` deep: the item
    /// and, each side, the follow margin that keeps it clear of a
    /// fade (`ShelfOverflow.followMargin`).
    public static func hardFloor(
        activeExtent: CGFloat,
        thickness: CGFloat,
        gap: CGFloat
    ) -> CGFloat {
        activeExtent + fadeRoom(thickness: thickness, gap: gap)
    }

    /// Both follow margins' room at their widest: what a section
    /// keeps beyond its active item.
    public static func fadeRoom(
        thickness: CGFloat,
        gap: CGFloat
    ) -> CGFloat {
        2 * (ShelfOverflow.fadeLength(thickness: thickness) + gap)
    }

    /// The Space section's length: its need while both fit;
    /// past that it gives way to the App section down to `floor`
    /// and no further — never longer than its need.
    private static func spaceSection(
        room: CGFloat,
        spaceNeed: CGFloat,
        appNeed: CGFloat,
        floor: CGFloat
    ) -> CGFloat {
        min(spaceNeed, max(floor, room - appNeed), room)
    }

    /// Where a run `length` long starts on an edge `whole` long.
    private static func lead(
        _ length: CGFloat,
        in whole: CGFloat,
        _ alignment: KiwiShelf.Alignment
    ) -> CGFloat {
        let slack = max(whole - length, 0)
        switch alignment {
        case .start: return 0
        case .center: return slack / 2
        case .end: return slack
        }
    }
}
