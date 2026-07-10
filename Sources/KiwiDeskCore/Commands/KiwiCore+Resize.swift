import AppKit
import Foundation

/// The `resize` command, split out of `KiwiCore+Commands` for
/// file size: true 2-axis (#56) and, in stack, focus-aware
/// (#67). Everything resolves against the active space (#17):
/// base value and write target follow the space's own override,
/// never the global — so a CLI resize can't shift other spaces.
extension KiwiCore {
    func resize(_ args: [JSONValue]) -> CommandResponse {
        guard let axis = args.first?.stringValue,
            axis == "x" || axis == "y",
            let delta = args.dropFirst().first?.numberValue
        else {
            return .fail("expected axis (x|y) and delta")
        }
        guard let space = activeSpace else {
            return .fail("no active space")
        }
        let span =
            axis == "x"
            ? Double(NSScreen.main?.visibleFrame.width ?? 1920)
            : Double(NSScreen.main?.visibleFrame.height ?? 1080)
        let response: CommandResponse
        switch space.mode {
        case .bsp:
            response = resizeBsp(
                axis: axis,
                delta: delta,
                span: span,
                space: space
            )
        case .stack:
            response = resizeStack(
                axis: axis,
                delta: delta,
                span: span,
                space: space
            )
        case .scrolling:
            response = resizeScrollingSlot(delta, space: space)
        default:
            return .fail(
                "resize not supported in "
                    + space.mode.rawValue
            )
        }
        guard response.isSuccess else { return response }
        // Deliberately un-forced (unlike the `set_*` config
        // applies, AGENTS.md §5): the nudged value persists in
        // settings/state and re-applies on the next layout, so
        // the ±2 pt tolerance can only delay a sub-tolerance
        // step, never lose it — and forcing every keypress
        // would wobble windows that apps clamp.
        retile(
            animated: tiler.settings.animations.onWindowResize
        )
        return response
    }

    /// Per-axis BSP resize (#56): "x" moves the side-by-side
    /// splits, "y" the stacked splits — independent knobs. The
    /// delta's sign follows the FOCUSED window (#122): a slot
    /// in the second (right/bottom) region grows when the
    /// shared ratio DROPS, so +delta always grows the focused
    /// region — mouse-path parity (`MouseResize.translate`).
    private func resizeBsp(
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) -> CommandResponse {
        let bsp = tiler.settings.resolvedBsp(for: space.id)
        let signed =
            bspFocusSign(axis: axis, space: space)
            * delta
        if axis == "x" {
            let value = bsp.splitRatioH + signed / span
            tiler.settings.setSplitRatioH(
                min(max(value, 0.1), 0.9),
                for: space.id
            )
        } else {
            let value = bsp.splitRatioV + signed / span
            tiler.settings.setSplitRatioV(
                min(max(value, 0.1), 0.9),
                for: space.id
            )
        }
        return .ok()
    }

    /// Which way the shared BSP ratio must move so "grow"
    /// grows the FOCUSED window: +1 when its calculated slot
    /// sits in the first (left/top) half of the screen, -1 in
    /// the second — the same midpoint rule the mouse path
    /// infers a drag's side from. Unknown focus (none, or
    /// floating — no slot) keeps +1, the first-region
    /// direction (the pre-#122 behavior).
    private func bspFocusSign(
        axis: String,
        space: Space
    ) -> Double {
        guard let focused = space.focused,
            let slot = tiler.calculatedFrames(
                state: state
            )[focused],
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else { return 1 }
        let bounds = GeometryUtils.axVisibleFrame(of: screen)
        if axis == "x" {
            return slot.midX <= bounds.midX ? 1 : -1
        }
        return slot.midY <= bounds.midY ? 1 : -1
    }

    /// Focus-aware stack resize (#67). "x" moves the
    /// master/stack split in the direction that grows the
    /// FOCUSED window: focused in master → +delta raises the
    /// ratio, focused in the stack column → +delta lowers it
    /// (the column grows). "y" grows the focused window's
    /// vertical share of its column via the per-window weights.
    private func resizeStack(
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) -> CommandResponse {
        let stack = tiler.settings.resolvedStack(for: space.id)
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard axis == "y" else {
            // Unknown focus keeps the master-grows direction
            // (the pre-#67 behavior).
            let (master, _) = StackLayout.partition(
                tiled,
                masterCount: stack.masterCount
            )
            let inMaster =
                space.focused.flatMap { focused in
                    tiled.contains(focused)
                        ? master.contains(focused) : nil
                } ?? true
            let sign: Double = inMaster ? 1 : -1
            // Interactive writes cap at the display's effective
            // range (#44) — past it the layout clamps and the
            // stored value would only ratchet invisibly.
            let value = StackLayout.cappedRatioWrite(
                stack.masterRatio + sign * delta / span,
                base: stack.masterRatio,
                available: span,
                minSize: Double(tiler.settings.minWindowSize)
            )
            tiler.settings.setMasterRatio(
                min(max(value, 0.1), 0.9),
                for: space.id
            )
            return .ok()
        }
        guard let focused = space.focused,
            let column = StackLayout.column(
                containing: focused,
                in: tiled,
                masterCount: stack.masterCount
            )
        else { return .fail("no focused tiled window") }
        guard column.count > 1 else {
            return .fail("focused window is alone in its column")
        }
        // Convert the pt delta into a weight change: with
        // heights h = A·w/W, dh/dw = A·(W−w)/W², so the exact
        // step for dh = delta is dw = delta·W²/(A·(W−w)).
        // The screen span stands in for the column height A —
        // close enough for a keyboard nudge, and the layout
        // renormalizes whatever we store.
        let weightFloor = StackLayout.weightFloor
        let weights = column.map {
            max(space.stackWeights[$0] ?? 1, weightFloor)
        }
        let total = weights.reduce(0, +)
        let current = max(
            space.stackWeights[focused] ?? 1,
            weightFloor
        )
        let change =
            delta * total * total / (span * (total - current))
        var value = current + change
        if change > 0 {
            // Growing: cap the write where the smallest OTHER
            // share hits min_window_size — past that cliff the
            // layout falls back to the overflow cascade, which
            // ignores weights, so extra weight would only
            // ratchet invisibly (review). Never forced below
            // `current`, so an already-overflowed column stays
            // editable downwards.
            let others = zip(column, weights)
                .filter { $0.0 != focused }
                .map(\.1)
            if let smallest = others.min() {
                let limit = StackLayout.maxColumnTotal(
                    smallestWeight: smallest,
                    height: span,
                    minSize: Double(
                        tiler.settings.minWindowSize
                    )
                )
                let cap = limit - (total - current)
                value = min(value, max(cap, current))
            }
        }
        let range = StackLayout.weightRange
        value = min(
            max(value, range.lowerBound),
            range.upperBound
        )
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[focused] = value
        }
        return .ok()
    }

    /// The scrolling slot resizes along its own scroll axis,
    /// not the requested x/y axis. Take the current magnitude
    /// (stored pt as-is; auto/% seeded against the axis), add
    /// the delta, store as points. Screen basis matches the
    /// mouse-resize path (main screen — the pre-existing
    /// single-screen ceiling, see plan item 8).
    private func resizeScrollingSlot(
        _ delta: Double,
        space: Space
    ) -> CommandResponse {
        let scrolling =
            tiler.settings.resolvedScrolling(for: space.id)
        let horizontal = scrolling.barAxisIsHorizontal
        let screen = NSScreen.main ?? NSScreen.screens.first
        let bounds =
            screen.map { GeometryUtils.axVisibleFrame(of: $0) }
            ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let along = horizontal ? bounds.width : bounds.height
        let current = scrolling.slotSize
            .editablePoints(along: along, horizontal: horizontal)
        tiler.settings.setSlotSize(
            .points(clamping: current + CGFloat(delta)),
            for: space.id
        )
        return .ok()
    }
}
