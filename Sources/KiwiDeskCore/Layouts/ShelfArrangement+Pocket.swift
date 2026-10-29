import CoreGraphics

extension ShelfArrangement {
    /// The pocket's ask of a bar's edge (#2678): its natural length,
    /// and whether it takes the edge's end rather than its start
    /// (`KiwiShelf.pocketLeansEnd`).
    public struct PocketAsk: Equatable, Sendable {
        public var need: CGFloat
        public var leadsEnd: Bool

        public init(need: CGFloat, leadsEnd: Bool) {
            self.need = need
            self.leadsEnd = leadsEnd
        }
    }

    /// Places the bars and the pocket along an edge `length` long
    /// (#2678): the pocket is pinned at the strip's outer end on its
    /// side, whole, outside the bars' run, and the bars are placed in
    /// the room left after it and one gutter — so the bars scroll
    /// while the pocket never moves. A nil `pocket` places the bars
    /// alone. The one placement door: every caller states its pocket.
    public static func arrange(
        length: CGFloat,
        spaceNeed: CGFloat?,
        appNeed: CGFloat?,
        spaceFloor: CGFloat,
        shelf: KiwiShelf,
        pocket: PocketAsk?
    ) -> ShelfArrangement {
        guard let pocket else {
            return arrangeBars(
                length: length,
                spaceNeed: spaceNeed,
                appNeed: appNeed,
                spaceFloor: spaceFloor,
                shelf: shelf
            )
        }
        let whole = max(length, 0)
        let need = min(max(pocket.need, 0), whole)
        let gutter = max(shelf.itemGap, KiwiShelf.minItemGap)
        let room = max(whole - need - gutter, 0)
        var placed = arrangeBars(
            length: room,
            spaceNeed: spaceNeed,
            appNeed: appNeed,
            spaceFloor: spaceFloor,
            shelf: shelf
        )
        let shift = pocket.leadsEnd ? 0 : need + gutter
        placed.space?.offset += shift
        placed.app?.offset += shift
        placed.pocket = Slot(
            offset: pocket.leadsEnd ? whole - need : 0,
            length: need,
            alignment: .center
        )
        return placed
    }
}
