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
        // Resize is the ONE focused verb that resolves against
        // `space.focused`, not the focus anchor: every path below
        // writes id-keyed per-space state (BSP/stack/track ratios
        // and per-window weights), and keying that under a
        // non-member traveler id would orphan it (never pruned,
        // recycled-id hazard #308). A future per-space-keyed resize
        // sibling belongs on this same local-focus side — the rest
        // of the focused verbs use the anchor. See the
        // resize-stays-local row in docs/design-decisions.md.
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
        // Span resolves on the space's OWN display (#449) —
        // main-screen math resized against the wrong bounds on
        // a secondary monitor — and on the LAYOUT REGION of it,
        // not the raw frame (#537): a delta divided by a span the
        // Space Bar's strip inflates understates every ratio it
        // writes, and the caps below share the same span.
        let bounds = TilingEngine.screen(
            for: space.id,
            in: state
        ).map { tiler.layoutBounds(on: $0) }
        let span =
            axis == "x"
            ? Double(bounds?.width ?? 1920)
            : Double(bounds?.height ?? 1080)
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
        //
        // The canonical `.resize` pass (#593): membership and slot
        // assignment are untouched, every path above only rewrites
        // a ratio or weight, and nothing here is instantly sized —
        // so a yielding pane may slide its shared edge instead of
        // snapping.
        retile(
            animated: tiler.settings.animations.onWindowResize,
            sizeIntent: .resize
        )
        // Resizing a track past min_window_size flips it into an
        // overflow cascade (or unflips one back); fix the pile's
        // z-order once it settles (#193, self-gated).
        scheduleTrackZOrderRestoreIfOverflowing()
        return response
    }

    /// The scrolling slot resizes along its own scroll axis,
    /// not the requested x/y axis. Take the current magnitude
    /// (stored pt as-is; auto/% seeded against the axis), add
    /// the delta, store as points. Screen basis matches the
    /// mouse-resize path: the space's own display (#449), and its
    /// layout region rather than the raw frame (#537) — this is
    /// the one resize path whose span becomes a *stored* value,
    /// so a strip-wide span mis-seeds the slot itself, not just
    /// the size of one nudge.
    private func resizeScrollingSlot(
        _ delta: Double,
        space: Space
    ) -> CommandResponse {
        let scrolling =
            tiler.settings.resolvedScrolling(for: space)
        let horizontal = scrolling.axisIsHorizontal
        let screen = TilingEngine.screen(
            for: space.id,
            in: state
        )
        let bounds =
            screen.map { tiler.layoutBounds(on: $0) }
            ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let along = horizontal ? bounds.width : bounds.height
        let current = scrolling.slotSize
            .editablePoints(along: along, horizontal: horizontal)
        writeSlotSize(
            .points(clamping: current + CGFloat(delta)),
            for: space.id
        )
        return .ok()
    }
}
