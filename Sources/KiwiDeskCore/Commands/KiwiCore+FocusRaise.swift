import AppKit
import Foundation

/// The deferred scrolling focus raise (#143/#878).
///
/// In scrolling mode a focus move pans the viewport, and the
/// raise must never hide the motion: whatever MOVES owns the
/// foreground while the pan runs, and the focused window is
/// front when it ends. A target the pan merely REVEALS — one
/// already sitting at its final frame, pinned at the vertical
/// top (#66/#139, where #143 was born) or at an edge walled by
/// a neighboring screen (#878) — is raised only at the settle:
/// raising it first pops it over the whole screen while the
/// others are still sliding off it. A target whose own frame
/// moves — sliding in from an open edge's void (#158), or
/// traveling to its seat under a re-seating anchor — is raised
/// first and rides in on top, keystrokes transferring
/// instantly. The frame comparison, not direction or topology,
/// is the predicate: direction proxies broke on re-seating
/// anchors, where a step toward a wall makes the target travel
/// and deferring hid that travel behind the previous focus.
///
/// Timing rides the same settle signal as the z-order restore
/// (`AnimationEngine.onAllAnimationsEnded`, dispatched by
/// `animationsDidSettle` in `KiwiCore+Settle`). Known trade,
/// documented in the Lua reference and accepted limitations:
/// keystrokes during the slide (one animation length,
/// 50–1000 ms) still reach the previously focused app; Carbon
/// hotkeys are unaffected.
extension KiwiCore {
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
            // Stamp for the sibling-report distrust (#465 QA),
            // pruning expired entries so the dictionary cannot
            // grow with never-echoed raises.
            let now = Date()
            selfRaiseStamps = selfRaiseStamps.filter {
                now.timeIntervalSince($0.value)
                    < Self.selfRaiseSiblingWindow
            }
            selfRaiseStamps[id] = now
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
        // The anchor, not `activeSpace?.focused`: stepping off a
        // tiled-sticky traveler must classify the scroll pan
        // direction from the traveler's slot, not from the stale
        // local focus (#431). Identical for any local focus.
        let previousFocused = activeSpace.flatMap { sp in
            state.focusAnchor(
                of: sp,
                tiled: state.effectiveTiledMembers(
                    of: sp,
                    activeSpace: sp.id
                )
            )
        }
        let space = state.workspaces.space(of: id)
        if let space {
            state.workspaces.focus(id, in: space)
        }
        // Scrolling defers the raise until the pan settles when
        // this focus change leaves the target's own frame where
        // it already is (#143/#878): a stationary target is
        // being REVEALED — the others slide off it — and
        // raising it first would pop it over the whole screen
        // and hide the very motion the scroll is. A target
        // whose frame moves is its own show: raise-first keeps
        // the visible motion on top and transfers keystrokes
        // instantly — as does the neighbor handoff after a
        // close. State focus stays immediate either way: the
        // layout needs it to compute the pan. Every other path
        // (monocle, static layouts, space switches, cross-space
        // focus) keeps raise-first: there the raise IS the
        // visible focus change.
        let defersRaise =
            refocusRetile
            && activeSpace?.mode.defersFocusRaise == true
            && space == state.workspaces.activeSpace
            && scrollTargetIsRevealed(
                id,
                previous: previousFocused
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
        if warp {
            warpMouseToFocused(id)
        }
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
        // across apps from a background app.
        //
        // SEMANTIC loop guard, the scrolling arm's shape (#689):
        // the restore's own closing re-assert (which calls back
        // here) targets the focus that is already current, so
        // `previousFocused == id` refuses it by construction.
        // This arm keyed on `zOrderRestoresInFlight == 0` until
        // #689: since #684 a sequence holds that counter until
        // its landings verify — and a monocle restore's floor
        // contains the frontmost app's key window, which a quiet
        // raise can never clear, so the drain always paid its
        // per-window limit (`ZOrderDrain.landingLimit`) and the
        // counter suppressed a GENUINE second restore for that
        // whole limit after every monocle bar click. A
        // same-window re-focus arms nothing, which is
        // also correct: the raise above already fronted it, and
        // its floor clearance is what the previous restore
        // verified. One residue: a re-assert while a tiled-
        // sticky traveler holds the system focus reads
        // `previousFocused` as the traveler and arms once more —
        // that restore's plan is empty (the traveler is already
        // frontmost) and its own re-assert is skipped by the
        // completion's focus guard, so it cannot loop.
        if activeSpace?.mode == .monocle, previousFocused != id {
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
        // Scrolling: a multi-slot JUMP leaves every window
        // between the old and the new focus stacked for the old
        // one, which the edge piles show (#674). A ±1 step never
        // does — the raise above fronts the new focus and that is
        // the whole change — so only a jump arms the restack. An
        // App Bar item carries an absolute `WindowID`, which is
        // how a click crosses several slots at once.
        //
        // The narrowness is load-bearing, not thrift. The restore
        // raises every tiled pile-mate through the blocking
        // ordered queue, and the tiled plane then sits above the
        // float layer until the next genuine focus event
        // re-raises it (#418) — arming that on every step would
        // bury floats routinely and drag ring and mark a restack
        // behind (`KiwiCore+Settle`).
        //
        // LAST in this function, after the deferred-raise block,
        // for the reason that block states: `scheduleZOrderRestore`
        // runs the restore inline when nothing is animating, so
        // arming above it would drain a pile onto `zOrderQueue`
        // before `pendingFocusRaise` was even set, and the
        // immediate `runPendingFocusRaise` would then race it.
        // Deliberately NOT guarded on `zOrderRestoresInFlight`
        // — the same semantic refusal as the monocle arm above
        // (#689): the restore's own closing re-assert targets
        // the focus that is current, so the jump distance is
        // zero and the jump test refuses it. The counter would
        // only ever suppress a REAL jump: a pile drain holds it
        // for as long as the sequence takes to verify its
        // landings — bounded since #684 at
        // `ZOrderDrain.landingLimit` a window and `restoreBudget`
        // a sequence — so a user stepping back and forth across
        // the row lands inside that window constantly and would
        // see every second jump silently skip its restack
        // (owner device QA, 2026-08-02).
        if scrollFocusJumpsSlots(to: id, from: previousFocused) {
            scheduleScrollingZOrderRestoreIfOverflowing()
        }
    }

    /// Whether a scrolling focus move crosses MORE than one
    /// tiled slot — the case a lone target raise cannot restack
    /// (#674). False for a ±1 step and for a re-focus of the same
    /// window. Compares tiled array indices, like
    /// `scrollFocusApproachesWall`: array order is scroll order.
    ///
    /// Also false when EITHER end is missing from the tiled row —
    /// a first focus, or one arriving from a focused float, which
    /// is `space.focused` and so never a tiled member. Without
    /// both indices there is no evidence a jump happened, and the
    /// two outcomes are not symmetric: a missed restack is pile
    /// order that the next real jump fixes, while a spurious one
    /// pays N blocking cross-process raises and leaves the tiled
    /// plane over the float layer (#418) — over the very float
    /// the user was just in, on the float→tile case. Guessing
    /// costs more than waiting.
    private func scrollFocusJumpsSlots(
        to target: WindowID,
        from previous: WindowID?
    ) -> Bool {
        guard let space = activeSpace, let previous else {
            return false
        }
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: space.id
        )
        guard let targetIndex = tiled.firstIndex(of: target),
            let previousIndex = tiled.firstIndex(of: previous)
        else { return false }
        return abs(targetIndex - previousIndex) > 1
    }

    /// Whether this focus change leaves the target's own frame
    /// where it already is — the STATIONARY REVEAL: the target
    /// sits pinned at a wall (the vertical top, #139, or a
    /// screen seam, #878) while the pan slides the others away
    /// to uncover it. Only then does the raise defer. The frame
    /// comparison subsumes direction, edge topology AND the
    /// anchor: `follow` reveals wall-pinned targets in place,
    /// while a re-seating anchor (`start`/`center`/`end`) makes
    /// the same target TRAVEL to its seat — a moving target
    /// raises first so its motion stays on top, which a
    /// direction proxy got wrong. Compared against the SAME
    /// frames the retile is about to apply
    /// (`calculatedFrames`), within the engine's already-there
    /// tolerance; a window with no known frame yet reads as
    /// moving, so a raise is never lost. Distance is
    /// irrelevant, so an App Bar jump across several slots
    /// classifies exactly like a step. A first focus and the
    /// close-handoff (`previous == target`) never defer.
    private func scrollTargetIsRevealed(
        _ target: WindowID,
        previous: WindowID?
    ) -> Bool {
        guard let previous, previous != target,
            let window = state.windows[target],
            let frame = tiler.calculatedFrames(
                state: state
            )[target]
        else { return false }
        return TilingEngine.close(window.frame, to: frame)
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
