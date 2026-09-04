import AppKit
import Foundation

/// The `resize` command, split out of `KiwiCore+Commands` for
/// file size: true 2-axis (#56) and, in stack, focus-aware
/// (#67). Everything resolves against the active space (#17):
/// base value and write target follow the space's own override,
/// never the global — so a CLI resize can't shift other spaces.
extension KiwiCore {
    /// `KiwiDesk.set_refusal_sound(bool)` (#184, widened
    /// #1255): mute or restore the sound every refusal pill
    /// carries. No retile — pure behavior toggle.
    func setRefusalSound(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected a boolean")
        }
        tiler.settings.refusalSound = on
        return .ok()
    }

    /// Whether a resize WRITE animates: the configured policy,
    /// except during a held glide, which writes INSTANTLY
    /// (#1082, owner ruling 2026-08-29). The glide already IS the
    /// motion — one write per display frame — so springing each
    /// frame would smooth an already-smooth signal and add
    /// ~100–200 ms of trailing behind the key. It also keeps the
    /// feature clear of #611: a glide frame retargets with a
    /// CHANGED target every frame, which is precisely the storm
    /// the settle watchdog cannot tell from a long drag, so a
    /// springing glide would generate that documented hole
    /// deliberately and leave `HoldGlide.maxRunSeconds` as its
    /// only net. Writing instantly creates no animation at all,
    /// so there is nothing to defer.
    ///
    /// Named for the WRITE rather than the retile since #1090:
    /// `resizeFloating` takes this too, and that path applies one
    /// frame and skips the layout pass entirely, so the former
    /// `resizeRetileAnimated` would have been a name that lied at
    /// half its call sites.
    ///
    /// It reaches that path because #1090 gave it a base that no
    /// longer needs an animation to exist. Until then this was
    /// safe on the tiled paths and ONLY there, because of what
    /// each measures from: every path the retile serves writes a
    /// stored ratio, weight or length and re-derives geometry
    /// from it (`calculatedFrames` is a pure recomputation), so
    /// an instant write leaves the next glide frame's base exact,
    /// while `resizeFloating` measures from a FRAME and an
    /// instant write creates no target to measure from. The
    /// hold-scoped record (`GlideCommandedBase`) is that missing
    /// base, and the argument for its lifetime is there.
    ///
    /// A held chord glides under Reduce Motion too (owner
    /// ruling, same date): a held-key resize is the keyboard's
    /// direct manipulation, which Reduce Motion does not suppress
    /// for the mouse either, and since these writes are instant
    /// for everyone no glide needs a second mechanism. An earlier
    /// version of this comment claimed that was already the whole
    /// answer, which was false while the floating path still
    /// re-based on `AnimationEngine.targetFrame` — with Reduce
    /// Motion on, animations off, or the engine disabled there
    /// was no target and it fell back to the echo-fed frame,
    /// losing 71% of a held resize (measured, #1090). It is true
    /// now because that path has a base of its own, not because
    /// the tiled half was ever enough.
    ///
    /// Reads the per-WRITE `isApplyingGlideStep`, never the
    /// hold's lifetime — `HoldGlide.isApplyingGlideStep` argues
    /// why, and `keys.isFiring` one screen up is the same shape
    /// of read. Who else may read it is pinned by count in
    /// `HoldGlideSeamTests`, rather than claimed here: a
    /// behavioural test cannot see a second reader appear (#614).
    var resizeWritesAnimated: Bool {
        !keys.isApplyingGlideStep
            && tiler.settings.animations.onWindowResize
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
            // a hotkey press cues — the Cmd+Z-with-nothing-
            // to-undo idiom — while CLI/IPC callers only read
            // the error JSON. Since #1255 it DRAWS as well as
            // sounds: this is the most reachable refusal in the
            // feature, and it was the one nobody could see.
            refuseResizeUnsupported(in: space)
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
        // The canonical promising pass (#593): membership and
        // slot assignment are untouched, every path above only
        // rewrites a ratio or weight, and both panes spring from
        // the old value to the new on one clock — so a yielding
        // pane may slide its shared edge instead of snapping.
        retile(
            animated: resizeWritesAnimated,
            sizing: .allSpringSized
        )
        // Resizing a track past min_window_size flips it into an
        // overflow cascade (or unflips one back); fix the pile's
        // z-order once it settles (#193, self-gated).
        //
        // A glide frame stands the arm down and pays it ONCE when
        // the hold ends (#1082, architect + code review
        // 2026-08-29). `scheduleZOrderRestore` runs immediately
        // when `activeCount == 0` and defers otherwise, so the
        // settle was this arm's COALESCER as much as its ordering
        // rule: with animated writes a whole hold cost one
        // restore, while a glide's instant writes make
        // `activeCount` zero on every frame and would fire a full
        // verified `raiseSequentially` per display frame —
        // 60–120 a second of ordered raises on the blocking
        // queue, each holding the mouse warp, with
        // `zOrderRestoresInFlight` never returning to zero.
        // #674's "arm narrowly" is exactly this clause; the pile
        // is scrambled at most once per hold, so paying it once
        // at the end is also the correct ordering.
        if !keys.isApplyingGlideStep {
            scheduleTrackZOrderRestoreIfOverflowing()
        }
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
        let screen = TilingEngine.screen(
            for: space.id,
            in: state
        )
        let bounds =
            screen.map { tiler.layoutBounds(on: $0) }
            ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        // Clamp + refusal cue via the shared writer (#933),
        // the same one the mouse `.scrollWidth` path calls.
        writeCappedScrollSlot(
            delta: delta,
            space: space,
            bounds: bounds
        )
        return .ok()
    }
}
