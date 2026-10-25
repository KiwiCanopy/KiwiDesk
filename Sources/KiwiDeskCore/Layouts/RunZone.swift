import CoreGraphics

/// One region a Stack zone, a Track track or a Grid's last track
/// lays its members along (#2235, #2541): the shared placement
/// each takes, so a zone that overflows scrolls the same way in
/// any.
public struct RunZone: Sendable, Equatable {
    /// Members in drawn order.
    public let members: [WindowID]
    public let region: CGRect
    /// Members stack top to bottom when true, else left to right.
    public let vertical: Bool
    /// Fixed cells the run shows, in drawn order — a fixed Grid's
    /// last track (#2541): at most this many windows, each in its
    /// cell only where its floor fits that cell, else the run lays
    /// them by floor and weight. Nil sizes the run from its
    /// members' floors alone.
    public let slots: [CGRect]?

    public init(
        members: [WindowID],
        region: CGRect,
        vertical: Bool,
        slots: [CGRect]? = nil
    ) {
        self.members = members
        self.region = region
        self.vertical = vertical
        self.slots = slots
    }

    /// The zones `mode` lays `tiled` along, nil for a layout that
    /// scrolls none or where every window piles over the whole
    /// area. The one switch every run reader takes.
    public static func zones(
        mode: LayoutMode,
        tiled: [WindowID],
        in context: LayoutContext
    ) -> [RunZone]? {
        switch mode {
        case .stack: StackLayout.zones(for: tiled, in: context)
        case .track: TrackLayout.zones(for: tiled, in: context)
        case .grid: GridLayout.zones(for: tiled, in: context)
        default: nil
        }
    }

    /// The run this zone draws, or nil where it draws none: every
    /// member fits at its weighted share, or the zone cannot hold
    /// even one window at the minimum size and piles whole.
    public func run(in context: LayoutContext) -> ZoneRun? {
        placement(in: context).run
    }

    /// Frames for every member.
    public func frames(in context: LayoutContext) -> [WindowID: CGRect] {
        guard !members.isEmpty else { return [:] }
        let plan = placement(in: context)
        if plan.piles {
            return OverlapStack.frames(
                for: members,
                in: region,
                minSize: context.minWindowSize
            )
        }
        guard let run = plan.run else {
            return Dictionary(
                uniqueKeysWithValues: zip(members, weightedRects(plan))
            )
        }
        let rects =
            cellRects(run, in: context)
            ?? run.frames(
                floors: plan.floors,
                weights: plan.weights,
                in: region,
                vertical: vertical,
                gap: plan.gap
            )
        let corner = TilingEngine.optimalHideCorner(
            neighbors: context.screenNeighbors
        )
        var frames: [WindowID: CGRect] = [:]
        for (index, member) in members.enumerated() {
            frames[member] =
                run.visible.contains(index)
                ? rects[index]
                : Self.parked(
                    member,
                    slot: rects[index],
                    corner: corner,
                    in: context
                )
        }
        return frames
    }

    /// The fixed cells as the run's frames, a hidden member handed
    /// the edge cell it waits beyond; nil unless every cell is
    /// filled by a window whose floor fits it — the cells' lengths
    /// differ once a column is lifted or resized (#763).
    private func cellRects(
        _ run: ZoneRun,
        in context: LayoutContext
    ) -> [CGRect]? {
        guard let slots, let first = slots.first, let last = slots.last,
            run.visible.count == slots.count,
            zip(run.visible, slots).allSatisfy({ index, slot in
                context.runFloor(of: members[index], horizontal: !vertical)
                    <= (vertical ? slot.height : slot.width)
            })
        else { return nil }
        return members.indices.map { index in
            if index < run.visible.lowerBound { return first }
            if index >= run.visible.upperBound { return last }
            return slots[index - run.visible.lowerBound]
        }
    }

    /// A hidden window's frame: its own learned size at the slot
    /// it waits for, parked at the hide corner (#881, #2235).
    private static func parked(
        _ id: WindowID,
        slot: CGRect,
        corner: TilingEngine.HideCorner,
        in context: LayoutContext
    ) -> CGRect {
        let own =
            context.sizeBounds[id]?
            .centered(in: slot, generalizing: !context.probesBeyondBounds)
            ?? slot
        return TilingEngine.stashFrame(
            own,
            in: context.parkBounds ?? context.bounds,
            corner: corner
        )
    }

    /// The span left to the weights once the shown members' floors
    /// are set aside — what a weight resize divides inside a run
    /// (`resizeStackMember`). Nil outside a run.
    public func runExtra(in context: LayoutContext) -> CGFloat? {
        let plan = placement(in: context)
        guard let run = plan.run else { return nil }
        let shown = Array(run.visible)
        let used =
            shown.reduce(CGFloat(0)) { $0 + plan.floors[$1] }
            + plan.gap * CGFloat(max(shown.count - 1, 0))
        return max(span - used, 0)
    }

    private struct Plan {
        let floors: [CGFloat]
        let weights: [Double]
        let gap: CGFloat
        let piles: Bool
        let run: ZoneRun?
    }

    /// Every reading a placement takes, each computed once.
    private func placement(in context: LayoutContext) -> Plan {
        let gap =
            vertical
            ? context.gaps.inner.vertical : context.gaps.inner.horizontal
        let cell = cellFloor(gap: gap)
        let floors = members.map {
            max(context.runFloor(of: $0, horizontal: !vertical), cell)
        }
        let weights = members.map {
            max(context.stackWeights[$0] ?? 1, StackLayout.weightFloor)
        }
        // The emergency whole-zone pile (#44): not even one window
        // fits at the minimum size.
        let piles =
            span <= 0
            || span < context.minWindowSize.along(horizontal: !vertical)
        guard !members.isEmpty, !piles,
            !fitsWhole(floors, weights, gap, context)
        else {
            return Plan(
                floors: floors,
                weights: weights,
                gap: gap,
                piles: piles,
                run: nil
            )
        }
        let run = ZoneRun.resolve(
            floors: floors,
            span: span,
            gap: gap,
            head: ZoneRun.head(of: members, in: context.runHeads),
            tail: ZoneRun.tail(of: members, in: context.runTails),
            focus: context.focused.flatMap { members.firstIndex(of: $0) }
        )
        return Plan(
            floors: floors,
            weights: weights,
            gap: gap,
            piles: false,
            run: run
        )
    }

    private var span: CGFloat { vertical ? region.height : region.width }

    /// Every member's floor under fixed cells: an equal cell's
    /// extent, rounded down so exactly `slots.count` fit the span.
    private func cellFloor(gap: CGFloat) -> CGFloat {
        guard let count = slots?.count, count > 0 else { return 0 }
        return ((span - gap * CGFloat(count - 1)) / CGFloat(count))
            .rounded(.down)
    }

    /// Every member's weighted share keeps the minimum size (#67)
    /// and its own floor; otherwise the run places them, each at
    /// its floor or more.
    private func fitsWhole(
        _ floors: [CGFloat],
        _ weights: [Double],
        _ gap: CGFloat,
        _ context: LayoutContext
    ) -> Bool {
        let available = span - gap * CGFloat(members.count - 1)
        let total = weights.reduce(0, +)
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            span: Double(available),
            minSize: Double(
                context.minWindowSize.along(horizontal: !vertical)
            )
        )
        guard available > 0, total <= limit else { return false }
        return zip(weights, floors).allSatisfy {
            available * CGFloat($0.0 / total) >= $0.1
        }
    }

    private func weightedRects(_ plan: Plan) -> [CGRect] {
        let available = span - plan.gap * CGFloat(members.count - 1)
        let total = plan.weights.reduce(0, +)
        var position = vertical ? region.minY : region.minX
        return plan.weights.map { weight in
            let extent = available * CGFloat(weight / total)
            defer { position += extent + plan.gap }
            return vertical
                ? CGRect(
                    x: region.minX,
                    y: position,
                    width: region.width,
                    height: extent
                )
                : CGRect(
                    x: position,
                    y: region.minY,
                    width: extent,
                    height: region.height
                )
        }
    }
}
