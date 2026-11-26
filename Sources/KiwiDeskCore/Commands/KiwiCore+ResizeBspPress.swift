import CoreGraphics
import Foundation

/// Whether a BSP keyboard press moves anything the press asks for
/// (#2969): judged on the layout at the ratio the press would write,
/// before it writes. The direction stays #122's midpoint rule.
extension KiwiCore {
    /// True where the press at `proposed` moves `focused` the
    /// press's way, or — for a window on no split of the axis — moves
    /// a mate, or where nothing on the axis divides, which the writer
    /// names (#1258, #1259). Otherwise cues the limit, naming a mate
    /// at its floor where there is one, and returns false: the press
    /// writes nothing and a hold ends. Judged on the laid-out slots,
    /// not the placed frames: a slot a floor overhang lands back
    /// inward can move while its drawn frame stays, a press this
    /// cannot see (the writer's under-clamp residue).
    func bspPressMoves(
        _ focused: WindowID,
        axis: String,
        delta: Double,
        to proposed: Double,
        space: Space
    ) -> Bool {
        guard let screen = TilingEngine.screen(for: space.id, in: state)
        else { return true }
        let input = tiler.layoutInput(
            state: state,
            space: space,
            screen: screen
        )
        guard input.tiled.contains(focused) else { return true }
        let horizontal = axis == "x"
        func frames(at ratio: Double) -> [WindowID: CGRect] {
            var context = input.context
            if horizontal {
                context.bsp.splitRatioH = Self.storedBspRatio(ratio)
            } else {
                context.bsp.splitRatioV = Self.storedBspRatio(ratio)
            }
            return LayoutEngine.calculate(
                mode: input.space.mode,
                windows: input.tiled,
                context: context
            )
        }
        func length(_ frame: CGRect?) -> CGFloat {
            frame.map { horizontal ? $0.width : $0.height } ?? 0
        }
        let base =
            horizontal
            ? input.context.bsp.splitRatioH : input.context.bsp.splitRatioV
        let now = frames(at: base)
        let next = frames(at: proposed)
        let sides = BspSplit.sides(
            of: input.tiled,
            slots: now,
            bounds: tiler.layoutBounds(on: screen, for: space),
            horizontal: horizontal,
            chain: bspChain(of: space, on: screen)?.zone
        )
        let mates = sides.first + sides.second
        guard !mates.isEmpty else { return true }
        let moved: Bool
        let inSplit = mates.contains(focused)
        if inSplit {
            let change = length(next[focused]) - length(now[focused])
            moved = change * (delta < 0 ? -1 : 1) > Self.pressMovesTolerance
            // The opposite press would do what was asked (#3643): the
            // shared ratio moves this window against the press.
            let opposite = frames(at: base - (proposed - base))
            let back = length(opposite[focused]) - length(now[focused])
            if !moved,
                back * (delta < 0 ? 1 : -1) < -Self.pressMovesTolerance
            {
                refuseRatioMovesOtherWay(
                    focused,
                    axis: axis,
                    grows: delta > 0
                )
                return false
            }
        } else {
            moved = mates.contains {
                abs(length(next[$0]) - length(now[$0]))
                    > Self.pressMovesTolerance
            }
        }
        guard !moved else { return true }
        // The side the ratio's move squeezes, read off the move's own
        // direction as the writer reads its binding side.
        let squeezed = proposed < base ? sides.first : sides.second
        cueBspLimit(
            focused,
            axis: axis,
            delta: delta,
            squeezed: squeezed,
            atBound: Self.bspRatioSpent(base, to: proposed),
            inSplit: inSplit,
            now
        )
        return false
    }

    /// Below this many points a trial moved nothing.
    private static let pressMovesTolerance: CGFloat = 0.01

    /// The cue for a BSP press that moves nothing it asks for. A
    /// floor wins over the ratio's limit: the mate on the `squeezed`
    /// side nearest `focused` sitting at its floor (#1259's blame),
    /// else the window's own floor on a shrink, else the largest or
    /// smallest share — the stored bound, or for a window `inSplit`
    /// the most the shared ratio gives it (#3643) — else the boundary.
    private func cueBspLimit(
        _ focused: WindowID,
        axis: String,
        delta: Double,
        squeezed: [WindowID],
        atBound: Bool,
        inSplit: Bool,
        _ frames: [WindowID: CGRect]
    ) {
        let horizontal = axis == "x"
        func length(_ id: WindowID) -> Double {
            Double(
                frames[id].map { horizontal ? $0.width : $0.height } ?? 0
            )
        }
        let centre = frames[focused].map { CGPoint(x: $0.midX, y: $0.midY) }
        let atFloor = squeezed.filter {
            $0 != focused
                && length($0) <= plannedMinSize(of: $0, axis: axis) + 1
        }
        let stuck = atFloor.min { a, b in
            func distance(_ id: WindowID) -> CGFloat {
                guard let centre, let frame = frames[id] else { return 0 }
                return hypot(frame.midX - centre.x, frame.midY - centre.y)
            }
            return distance(a) < distance(b)
        }
        let atOwnFloor =
            length(focused) <= plannedMinSize(of: focused, axis: axis) + 1
        if let stuck {
            refuseGrowAtNeighborMinimum(focused, anchor: stuck, axis: axis)
        } else if delta < 0, atOwnFloor || !atBound {
            refuseShrinkAtMinimum(focused, axis: axis)
        } else if atBound || inSplit {
            refuseRatioLimit(focused, axis: axis, grows: delta > 0)
        } else {
            refuseGrowAtBoundary(focused, axis: axis)
        }
    }
}
