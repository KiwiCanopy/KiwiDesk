import AppKit
import Foundation

/// The `resize` command, split out of `KiwiCore+Commands` for
/// file size: true 2-axis (#56) and, in stack, focus-aware
/// (#67). Everything resolves against the active space (#17):
/// base value and write target follow the space's own override,
/// never the global — so a CLI resize can't shift other spaces.
extension KiwiCore {
    /// The unsupported-command cue seam (#184): the system
    /// alert sound, only when the failing command runs inside a
    /// hotkey fire (`KeybindingManager.isFiring`) and the
    /// `resize.feedback` toggle is on. CommandResponse.fail
    /// stays the CLI/IPC contract either way. Route future
    /// hotkey no-ops through here so they inherit the cue —
    /// deliberately NOT wired to every `.fail` today: routine
    /// edge failures (focus at a row's end) would beep on
    /// every press.
    func cueUnsupportedCommand() {
        guard keys.isFiring,
            tiler.settings.resizeFeedback
        else { return }
        NSSound.beep()
    }

    /// `KiwiDesk.set_resize_feedback(bool)` (#184): mute or
    /// restore the cue. No retile — pure behavior toggle.
    func setResizeFeedback(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected a boolean")
        }
        tiler.settings.resizeFeedback = on
        return .ok()
    }

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
        // A floating focused window resizes ITSELF, in every
        // layout mode — it does not participate in the layout,
        // so the ratio paths below (and their unknown-focus
        // fallbacks) never see a floating focus.
        if let focused = space.focused,
            state.windows[focused]?.isFloating == true
        {
            return resizeFloating(
                focused,
                axis: axis,
                delta: delta
            )
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
        case .track:
            response = resizeTrack(
                axis: axis,
                delta: delta,
                span: span,
                space: space
            )
        default:
            // Correct no-op (macOS full-screen/Stage Manager
            // expose no resize either), but perceivable (#184):
            // a hotkey press beeps — the Cmd+Z-with-nothing-
            // to-undo idiom — while CLI/IPC callers only read
            // the error JSON.
            cueUnsupportedCommand()
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
        // Resizing a track past min_window_size flips it into an
        // overflow cascade (or unflips one back); fix the pile's
        // z-order once it settles (#193, self-gated).
        scheduleTrackZOrderRestoreIfOverflowing()
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
    /// grows the FOCUSED window — the mouse path's side rule,
    /// via the shared authority (`MouseResize.bspSide`).
    /// Unknown focus (none, or floating — no slot) keeps +1,
    /// the first-region direction (the pre-#122 behavior).
    /// Assumes `space` IS the active space: the slot lookup
    /// resolves the active space's frames only, so any other
    /// space silently gets the +1 fallback.
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
        return Double(
            MouseResize.bspSide(
                slot: slot,
                bounds: GeometryUtils.axVisibleFrame(
                    of: screen
                ),
                horizontal: axis == "x"
            )
        )
    }

    /// Focus-aware stack resize (#67), arrangement-aware
    /// (#222). The split axis (x for a left/right stack zone,
    /// y for top/bottom) moves the master/stack split in the
    /// direction that grows the FOCUSED window: focused in
    /// master → +delta raises the ratio, focused in the stack
    /// zone → +delta lowers it (the zone grows). The other
    /// axis grows the focused window's share of its zone via
    /// the per-window weights — but only when the zone lines
    /// up along that axis; a zone has no cross-axis parameter,
    /// so that resize fails like any unsupported axis.
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
        let splitAxis =
            stack.stackPosition.splitsHorizontally ? "x" : "y"
        guard axis != splitAxis else {
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
        // The weight axis is the focused zone's own axis: a
        // vertical zone divides heights ("y"), a horizontal one
        // widths ("x"). The stack zone's axis derives from the
        // position (#222) and is always orthogonal to the split;
        // only a master zone oriented along the split axis has
        // no cross-axis parameter — perceivable no-op like
        // unsupported modes (#184).
        let (master, _) = StackLayout.partition(
            tiled,
            masterCount: stack.masterCount
        )
        let orientation =
            master.contains(focused)
            ? stack.masterOrientation
            : stack.stackPosition.stackOrientation
        let weightAxis =
            orientation == .vertical ? "y" : "x"
        guard axis == weightAxis else {
            cueUnsupportedCommand()
            return .fail(
                "no \(axis) parameter for this arrangement"
            )
        }
        guard let focusOffset = column.firstIndex(of: focused),
            column.count > 1
        else {
            return .fail("focused window is alone in its column")
        }
        // The step math (delta → weight change, grow cap,
        // clamp) is the shared #67/#128 authority; the screen
        // span stands in for the column height A — close enough
        // for a keyboard nudge, and the layout renormalizes
        // whatever we store.
        let weightFloor = StackLayout.weightFloor
        let weights = column.map {
            max(space.stackWeights[$0] ?? 1, weightFloor)
        }
        let index =
            column.distance(
                from: column.startIndex,
                to: focusOffset
            )
        let value = StackLayout.weightStep(
            weights: weights,
            at: index,
            delta: delta,
            span: span,
            minSize: Double(tiler.settings.minWindowSize)
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
