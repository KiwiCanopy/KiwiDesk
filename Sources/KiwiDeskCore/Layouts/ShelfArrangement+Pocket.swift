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
    /// side, whole, outside the bars' run. The bars take their
    /// lengths from the room left after it, their run's own end pad
    /// the one separation (#2776), and keep their alignment against
    /// the whole edge, the pocket's slot only bounding them (#3685)
    /// — so the bars scroll while the pocket never moves. A nil
    /// `pocket` places the bars alone. The one placement door: every
    /// caller states its pocket.
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
        let free = pocket.leadsEnd ? 0...room : need...whole
        placed.place(
            within: free,
            whole: whole,
            needs: (spaceNeed, appNeed),
            alignment: shelf.alignment
        )
        placed.pocket = Slot(
            offset: pocket.leadsEnd ? whole - need : 0,
            length: need,
            alignment: .center
        )
        return placed
    }

    /// Moves the bars, laid out in a room `free.length` long from
    /// zero, into `free`: their run takes its `alignment` against
    /// the `whole` edge and is clamped into `free` (#3685). A lone
    /// bar keeps all of `free` under `start` and `end`; a centred
    /// one takes the widest stretch of `free` centred on its run.
    private mutating func place(
        within free: ClosedRange<CGFloat>,
        whole: CGFloat,
        needs: (space: CGFloat?, app: CGFloat?),
        alignment: KiwiShelf.Alignment
    ) {
        let room = free.upperBound - free.lowerBound
        let slots = [space, app].compactMap { $0 }
        guard let first = slots.map(\.offset).min() else { return }
        let end = slots.map { $0.offset + $0.length }.max() ?? first
        let run: CGFloat
        if slots.count == 1 {
            let need = needs.space ?? needs.app ?? 0
            run = min(need, room)
        } else {
            run = end - first
        }
        let lead = min(
            max(
                Self.lead(run, in: whole, alignment),
                free.lowerBound
            ),
            free.upperBound - run
        )
        guard slots.count == 1, alignment == .center else {
            let shift = slots.count == 1 ? free.lowerBound : lead - first
            space?.offset += shift
            app?.offset += shift
            return
        }
        let middle = lead + run / 2
        let half = min(middle - free.lowerBound, free.upperBound - middle)
        let slot = Slot(
            offset: middle - half,
            length: 2 * half,
            alignment: .center
        )
        if space != nil { space = slot } else { app = slot }
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
