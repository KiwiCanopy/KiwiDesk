import AppKit
import Foundation

/// The BSP half of the `resize` command, split out of
/// `KiwiCore+Resize` for file size (like `+ResizeFloating` and
/// `+ResizeStack`): the per-axis ratio write and the
/// focused-window sign rule.
extension KiwiCore {
    /// Per-axis BSP resize (#56): "x" moves the side-by-side
    /// splits, "y" the stacked splits — independent knobs. The
    /// delta's sign follows the FOCUSED window (#122): the ratio
    /// moves the way that grows it on a +delta, judged on the
    /// layout (#2969), and a press neither way honours cues.
    func resizeBsp(
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) -> CommandResponse {
        // A press along a scrolled chain is a run weight (#2542).
        if let focused = space.focused,
            let response = resizeBspChain(
                focused,
                axis: axis,
                delta: delta,
                space: space,
                toward: .both
            )
        {
            return response
        }
        let bsp = tiler.settings.resolvedBsp(
            for: space,
            session: sessionRatios(of: space.id)
        )
        let base =
            axis == "x" ? bsp.splitRatioH : bsp.splitRatioV
        guard
            let sign = bspRatioSign(
                axis: axis,
                delta: delta,
                span: span,
                base: base,
                space: space
            )
        else {
            // No move of the one ratio sizes the window the press's
            // way: a limit reached, which ends a hold (#2969).
            if let focused = space.focused {
                if delta < 0 {
                    refuseShrinkAtMinimum(focused, axis: axis)
                } else {
                    refuseGrowAtBoundary(focused, axis: axis)
                }
            }
            return .ok()
        }
        let signed = sign * delta
        // Cap the write at the layout region's effective range
        // (#383): past it the layout clamps anyway and the stored
        // value would only ratchet invisibly, exactly like the
        // stack path (#44). Span is the region before outer gaps
        // (#537) — still a superset of the gap-adjusted range the
        // layout divides, so the cap never blocks reaching the
        // visible bound, but no longer a superset by the Space
        // Bar's whole strip, which let the ratchet back in.
        // Two-sided since #933: each side of the first split
        // carries its own windows' effective minimums, and a
        // truncated write cues the refusal.
        writeCappedBspRatio(
            proposed: base + signed / span,
            axis: axis,
            span: span,
            space: space,
            focused: space.focused
        )
        return .ok()
    }

    /// Which way the shared ratio moves for `delta` to size the
    /// FOCUSED window the press's way, judged on the layout itself:
    /// one ratio sizes every split on its axis, so a window leading
    /// one split and trailing another peaks short of either end, and
    /// a side read off its slot flips as it crosses the midpoint
    /// (#2969). Nil where neither way does, at the store's own
    /// 0.1...0.9 bound included, and for a window on no split of the
    /// axis where no mate moves either; +1 where the focus has no slot
    /// (the pre-#122 behavior) or the window's press still sizes a
    /// mate.
    private func bspRatioSign(
        axis: String,
        delta: Double,
        span: Double,
        base: Double,
        space: Space
    ) -> Double? {
        guard let focused = space.focused,
            let screen = TilingEngine.screen(for: space.id, in: state)
        else { return 1 }
        let input = tiler.layoutInput(
            state: state,
            space: space,
            screen: screen
        )
        func frames(at ratio: Double) -> [WindowID: CGRect] {
            var context = input.context
            let stored = min(max(ratio, 0.1), 0.9)
            if axis == "x" {
                context.bsp.splitRatioH = stored
            } else {
                context.bsp.splitRatioV = stored
            }
            return BspLayout().calculateGeometry(
                for: input.tiled,
                in: context
            )
        }
        func length(_ frame: CGRect?) -> CGFloat? {
            frame.map { axis == "x" ? $0.width : $0.height }
        }
        let current = frames(at: base)
        guard input.tiled.contains(focused),
            let now = length(current[focused])
        else { return 1 }
        let sense: CGFloat = delta < 0 ? -1 : 1
        let trials = [1.0, -1.0].map { sign in
            (sign, frames(at: base + sign * delta / span))
        }
        let changes = trials.map { sign, moved in
            (sign, (length(moved[focused]) ?? now) - now)
        }
        // A window on no split of the axis is the writer's to cue,
        // naming the axis or the arrangement (#1258, #1259), while
        // its press still sizes a mate; once none moves, it is a
        // limit reached like any other.
        let sides = BspSplit.sides(
            of: input.tiled,
            slots: tiler.calculatedFrames(state: state),
            bounds: tiler.layoutBounds(on: screen, for: space),
            horizontal: axis == "x",
            chain: bspChain(of: space, on: screen)?.zone
        )
        guard sides.first.contains(focused) || sides.second.contains(focused)
        else {
            let divides = !sides.first.isEmpty || !sides.second.isEmpty
            let mateMoves = trials[0].1.contains { id, frame in
                guard let was = current[id] else { return true }
                return abs(frame.width - was.width) > 0.5
                    || abs(frame.height - was.height) > 0.5
            }
            return divides && !mateMoves ? nil : 1
        }
        let tolerance = RunZone.unchangedTolerance
        return
            changes
            .filter { $0.1 * sense > tolerance }
            .max { $0.1 * sense < $1.1 * sense }?.0
    }
}
