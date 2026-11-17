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

    /// The pocket's length along an edge `depth` deep: its mark, and
    /// room each side for the mark's lit edge and lift (#2776).
    public static func pocketNeed(depth: CGFloat) -> CGFloat {
        let mark = PocketMarkGeometry.markSide(depth: depth)
        return mark + 2 * PocketMarkGeometry.spill(mark: mark)
    }

    /// The pocket's slot along an edge `depth` deep: its need, and
    /// on an edge that draws nothing at rest (`asHandle`), where it
    /// rests as its handle or its whole mark, no less than the
    /// handle's band, so it stands in its slot and off the bars'
    /// runs (#3432).
    public static func pocketNeed(
        depth: CGFloat,
        asHandle: Bool
    ) -> CGFloat {
        let need = pocketNeed(depth: depth)
        return asHandle ? max(need, ShelfMarkPlacement.bandLength) : need
    }

    /// Places the bars and the pocket along an edge `length` long
    /// (#2678): the pocket is pinned at the strip's outer end on its
    /// side, whole, outside the bars' run, and the bars are placed in
    /// the room left after it, their run's own end pad the one
    /// separation (#2776) — so the bars scroll while the pocket never
    /// moves. A nil `pocket` places the bars
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
        let room = max(whole - need, 0)
        var placed = arrangeBars(
            length: room,
            spaceNeed: spaceNeed,
            appNeed: appNeed,
            spaceFloor: spaceFloor,
            shelf: shelf
        )
        let shift = pocket.leadsEnd ? 0 : need
        placed.space?.offset += shift
        placed.app?.offset += shift
        placed.pocket = Slot(
            offset: pocket.leadsEnd ? whole - need : 0,
            length: need,
            alignment: .center
        )
        return placed
    }

    /// The arrangement with only `bars`' slots kept (#3359): each
    /// keeps its offset, so a bar drawn while its sibling rests as
    /// a handle stands where the pair places it. The divider goes
    /// with either bar; the pocket's slot is the plan's to drop
    /// (`KiwiCore.ShelfPlan.arrangement`, #3432).
    public func keeping(_ bars: Set<ShelfBar>) -> ShelfArrangement {
        var kept = self
        if !bars.contains(.space) { kept.space = nil }
        if !bars.contains(.app) { kept.app = nil }
        if kept.space == nil || kept.app == nil { kept.divider = nil }
        return kept
    }
}
