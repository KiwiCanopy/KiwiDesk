import AppKit
import Foundation

/// The deferred scrolling focus raise (#143).
///
/// In scrolling mode a focus move pans the viewport. Raising
/// the target first is jarring when focusing *up*: the row
/// above sits pinned at the top border BEHIND the current
/// window (#66/#139), and an immediate raise pops it over the
/// whole screen before the slide starts. Deferred, the current
/// window slides away and gradually reveals the pinned row;
/// front and keyboard focus land when the pan does.
///
/// Timing rides the same settle signal as the z-order restore
/// (`AnimationEngine.onAllAnimationsEnded` — the shared slot in
/// `KiwiCore.init` runs both). Known trade, documented in the
/// Lua reference and accepted limitations: keystrokes during
/// the slide (one animation length, 50–1000 ms) still reach
/// the previously focused app; Carbon hotkeys are unaffected.
extension KiwiCore {
    /// The one `onAllAnimationsEnded` consumer — the slot is a
    /// single callback by design; this method IS the dispatch.
    /// Two pending-flag clients today, order-insensitive (the
    /// z-order restore's async pile raises end by re-asserting
    /// the focused window on top, healing any interleaving
    /// with the synchronous focus raise). Fork this into a
    /// real dispatcher only when (a) a third pending consumer
    /// appears, (b) ordering between the runners becomes
    /// semantic, or (c) a client needs per-monitor/per-space
    /// settle instead of the global count-zero signal.
    func animationsDidSettle() {
        runPendingZOrderRestore()
        runPendingFocusRaise()
    }

    /// Fires a pending deferred raise. Called when animations
    /// settle, and directly by `focusWindow` when no animation
    /// started. Re-validates at fire time: a newer focus
    /// command, a real focus echo (user click mid-pan), or a
    /// destroyed target have superseded the raise — drop it
    /// silently rather than steal focus back.
    func runPendingFocusRaise() {
        guard let id = pendingFocusRaise else { return }
        pendingFocusRaise = nil
        guard id == activeSpace?.focused else { return }
        raiseWindow(id)
    }

    /// The one AX raise call behind both the immediate and the
    /// deferred focus paths.
    func raiseWindow(_ id: WindowID) {
        if let window = state.windows[id],
            let element = eventLoop.element(for: id)
        {
            // Remember what we raised so its focus echo can be
            // told apart from a user's click (#152). A set: a
            // forward-immediate raise can fire while a backward
            // raise is still unechoed (#158).
            outstandingSelfRaises.insert(id)
            AXHelper.raise(element, pid: window.pid)
        }
    }

    /// Focuses a window: state, AX raise, and — only for
    /// focus-driven layouts (Scrolling, Monocle) — a retile.
    /// Static layouts skip it: their targets are unchanged,
    /// and re-applying them just fights apps that clamp our
    /// frames (grid-snapping terminals), wobbling everything.
    /// In scrolling, the raise waits for the pan to settle
    /// (#143, see `runPendingFocusRaise`).
    ///
    /// `refocusRetile: false` suppresses that retile for callers
    /// that just retiled themselves — a space switch already
    /// placed windows with the correct focus, and re-tiling here
    /// would spring them from their stale stash-corner frames
    /// (the AX echo of the instant switch has not landed yet),
    /// which is the "fly out of the corner" bug (issue #11).
    public func focusWindow(
        _ id: WindowID,
        refocusRetile: Bool = true,
        warp: Bool
    ) {
        let previousFocused = activeSpace?.focused
        let space = state.workspaces.space(of: id)
        if let space {
            state.workspaces.focus(id, in: space)
        }
        // Scrolling defers the raise until the pan settles
        // (#143), but only when stepping *backward* toward the
        // row pinned behind the leading edge (up/left): raising
        // it first pops that pinned row over the whole screen
        // before the slide even starts. Stepping forward
        // (down/right) — and the neighbor handoff after a close —
        // raises immediately, so the newly focused window lays on
        // top as it slides in instead of waiting out the pan.
        // State focus stays immediate either way: the layout
        // needs it to compute the pan. Every other path (monocle,
        // static layouts, space switches, cross-space focus)
        // keeps raise-first: there the raise IS the visible
        // focus change.
        let defersRaise =
            refocusRetile
            && activeSpace?.mode.defersFocusRaise == true
            && space == state.workspaces.activeSpace
            && scrollFocusStepsBackward(
                to: id,
                from: previousFocused
            )
        if !defersRaise {
            raiseWindow(id)
        }
        // Mouse follows focus (#186) fires at the intent point,
        // strictly AFTER the raise: synthetic CG mouse activity
        // right before `NSRunningApplication.activate()` can
        // make macOS's cooperative activation drop the request
        // (raise lands, key focus doesn't). State focus is set
        // (scrolling slot frames final); the raise echo is a
        // self-echo that must not warp twice. `warp: false`
        // marks mouse-made focus (drag drop, resize settle),
        // where the button is already up.
        if warp { warpMouseToFocused(id) }
        guard refocusRetile,
            activeSpace?.mode.isFocusDriven == true
        else {
            // Unreachable while `defersFocusRaise` stays a
            // subset of `isFocusDriven` — but if that drifts,
            // never lose the raise.
            if defersRaise { raiseWindow(id) }
            return
        }
        retileWithScrollDuration()
        // Monocle overlaps every window at one full-screen frame and
        // has no other z-order backstop (stack/scrolling/track arm
        // their own on their nav paths), so a focus change must
        // re-assert stacking through the reliable ordered raise —
        // the lone `AXHelper.raise` above works only intermittently
        // across apps from a background app. Guard on the in-flight
        // count so the restore's own closing re-assert (which calls
        // back here) can't re-arm and loop (owner 2026-07-20).
        if activeSpace?.mode == .monocle, zOrderRestoresInFlight == 0
        {
            scheduleZOrderRestore()
        }
        // Armed only AFTER the retile: retiling cancels
        // in-tolerance animations one by one, and the settle
        // callback fires synchronously the moment the count
        // hits zero — a pending raise armed before that would
        // fire mid-retile, ahead of the new pan (the #143 pop
        // again). Nothing can interleave between these
        // synchronous main-actor statements.
        if defersRaise {
            pendingFocusRaise = id
            // No pan in flight (target already visible, or
            // animations off): raise immediately — the
            // deferral must not regress non-animated paths.
            if tiler.animation.activeCount == 0 {
                runPendingFocusRaise()
            }
        }
    }

    /// Whether a scrolling focus move steps to an earlier slot
    /// than the previously focused window — the row pinned behind
    /// the leading edge. Only that direction defers the raise
    /// (#143); stepping forward, a first focus, and the
    /// close-handoff (`previous == target`) all raise at once.
    /// Compares tiled array indices: array order is scroll order,
    /// so a lower index is up/left along the resolved axis.
    private func scrollFocusStepsBackward(
        to target: WindowID,
        from previous: WindowID?
    ) -> Bool {
        guard let previous, previous != target,
            let space = activeSpace
        else { return false }
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard let targetIndex = tiled.firstIndex(of: target),
            let previousIndex = tiled.firstIndex(of: previous)
        else { return false }
        return targetIndex < previousIndex
    }

    /// Whether a focus-driven re-layout animates. Scrolling's
    /// focus slide is toggleable (`on_scrolling`); other
    /// focus-driven modes (Monocle) always animate. Used by
    /// `retileWithScrollDuration`'s non-scrolling branch — the
    /// scrolling branch swaps in `scrollDurationMS` and always
    /// animates when `on_scrolling` is set.
    var focusRetileAnimated: Bool {
        activeSpace?.mode == .scrolling
            ? tiler.settings.animations.onScrolling : true
    }

    /// Retiles for a focus-driven layout, honouring
    /// `scrollDurationMS` when the active mode is scrolling and
    /// `onScrolling` is true — so scroll focus shifts animate at
    /// their own speed without touching the general duration.
    ///
    /// Safe to call on MainActor: `retile()` is synchronous and
    /// reads `durationMS` at call time, so the transient swap
    /// cannot race anything.
    func retileWithScrollDuration() {
        if activeSpace?.mode == .scrolling,
            tiler.settings.animations.onScrolling
        {
            let saved = tiler.animation.durationMS
            tiler.animation.durationMS =
                tiler.animation.scrollDurationMS
            retile(animated: true)
            tiler.animation.durationMS = saved
        } else {
            retile(animated: focusRetileAnimated)
        }
    }
}
