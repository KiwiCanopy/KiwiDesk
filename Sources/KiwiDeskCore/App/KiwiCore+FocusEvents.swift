import AppKit
import Foundation

/// The `.windowFocused` side effects — echo provenance, stale
/// re-report distrust, focus-follow scheduling, and the float
/// re-raise (#152/#158/#244/#418/#465). Split from
/// `KiwiCore+Events.swift` (350-line ceiling); called only from
/// `handle`.
extension KiwiCore {
    func handleWindowFocused(
        _ id: WindowID,
        effects: AppliedEffects
    ) {
        // Dismissing an ignored panel (Ghostty's quick
        // terminal) leaves the app frontmost and makes AX
        // re-report its managed main window — which may live
        // on another space — as focused. Following that
        // stale report switches spaces, or in a focus-driven
        // layout yanks focus to the main window on the
        // active space. The panel was flagged active while
        // it held focus (#21); consume the flag here and
        // restore the pre-panel focus instead of acting on
        // the report (#244). A focus landing on any other
        // app means the panel's app resigned frontmost, so
        // drop stale flags to keep a later genuine focus of
        // that app from being suppressed.
        if let pid = state.windows[id]?.pid {
            if ignoredPanelActive.remove(pid) != nil {
                // The report is spurious, but the id could
                // still be an outstanding self-raise; drop
                // it so a later genuine focus of this window
                // is not misread as our own echo (cf. the
                // .windowDestroyed cleanup in
                // KiwiCore+Events.swift).
                outstandingSelfRaises.remove(id)
                if let before = effects.focusBefore,
                    let space = state.workspaces.space(
                        of: before
                    )
                {
                    state.workspaces.focus(
                        before,
                        in: space
                    )
                }
                return
            }
            ignoredPanelActive.removeAll()
        }
        // A focus echo from our own z-order raise (#418/#425):
        // AX couples the raise with app activation, so raising a
        // float above the tiled plane, or a pile member during a
        // cascade restore, emits a focus echo for it. The raise
        // must not move focus or the active ring onto that window
        // — revert to the window the user actually reached and
        // drop the echo, leaving it raised. The stamped set never
        // holds the intended focus (the raisers skip it), so a
        // deliberate focus (a space switch onto a float; a click
        // on a pile-mate) is unstamped and falls through.
        // Never consumed for an echo of our OWN focus raise
        // (`outstandingSelfRaises`): a keyboard focus can land
        // on a window a pile restore stamped moments earlier,
        // and for a tiled-sticky traveler `focusBefore` stays
        // on the stale local slot (the membership guard keeps
        // `space.focused` off travelers), so `intended != id`
        // cannot clear it — the revert would undo a deliberate
        // focus and strand the ring off the truly focused
        // window (#431). The self-echo path below consumes the
        // outstanding entry; the stamp expires on its own.
        //
        // Nor for a report with CLICK provenance (#687): a
        // restore's echoes come from windows the user did not
        // click, so a fresh click that reached the reported
        // window is proof no echo can forge — without the
        // escape, the first click after a restack was consumed
        // (state reverted while macOS kept the click's focus,
        // splitting keystrokes from ring and pan until the
        // next focus event). The revert itself stays
        // state-only either way: OS focus during a sequence is
        // owned by its closing re-assert
        // (`raiseSequentially(thenFocus:)`), and re-asserting
        // per echo would fight the drain mid-sequence — see
        // docs/design-decisions.md.
        if let stamp = zOrderRaiseEchoes[id],
            Date().timeIntervalSince(stamp)
                < Self.zOrderRaiseEchoWindow,
            let intended = effects.focusBefore, intended != id,
            !outstandingSelfRaises.contains(id),
            !recentClickReached(id, now: Date())
        {
            zOrderRaiseEchoes[id] = nil
            if let space = state.workspaces.space(of: intended) {
                state.workspaces.focus(intended, in: space)
            }
            updateBorders()
            updateStickyMarks()
            return
        }
        // An activation re-report (#465 QA): raising window B
        // activates its app, and a lazy-AX app (Electron)
        // re-reports its OLD focused window A — same pid,
        // DIFFERENT window, possibly on another space — before
        // the raise of B lands app-internally. Acting on A
        // would schedule a focus-follow that yanks the user
        // to A's space right after they explicitly switched
        // away. While a raise of a same-app window is RECENT
        // (`selfRaiseStamps`, age-bounded so a never-echoed
        // raise cannot poison the app's hidden windows forever
        // — the `zOrderRaiseEchoWindow` lesson), distrust the
        // sibling report on a NON-visible space and — #496 —
        // on a space shown on ANOTHER display, unless a fresh
        // click landed inside the reported window: on two
        // monitors the app's most-recent sibling is typically
        // visible over there, and forced activation genuinely
        // keys it, so trusting the report teleported the user
        // cross-display. A clicked sibling is a user action
        // wherever it is (`recentClickInside`). Same-DISPLAY
        // visible siblings stay honored — in-app window cycling
        // must not be fought. Sticky windows are exempt too —
        // `space(of:)` is only their hidden HOME, the window
        // itself renders visibly (#414), and the follow is
        // already sticky-exempt so a sticky report cannot cause
        // the space-yank anyway. A genuine clickless focus of a
        // distrusted sibling (cmd-tab, in-app cross-display
        // cycle) inside the ~1 s window is the accepted trade —
        // the next focus event follows normally.
        let now = Date()
        if !outstandingSelfRaises.contains(id),
            let pid = state.windows[id]?.pid,
            state.windows[id]?.isSticky != true,
            selfRaiseStamps.contains(where: {
                $0.key != id
                    && state.windows[$0.key]?.pid == pid
                    && now.timeIntervalSince($0.value)
                        < Self.selfRaiseSiblingWindow
            }),
            distrustsSiblingSpace(of: id),
            !recentClickInside(id, now: now)
        {
            if let intended = effects.focusBefore,
                intended != id,
                let space = state.workspaces.space(
                    of: intended
                )
            {
                state.workspaces.focus(intended, in: space)
                // The app genuinely keyed the sibling (forced
                // activation resolves to its MRU window, #496):
                // reverting state alone would split state focus
                // from OS key focus. Re-assert the raise the
                // app overrode — DIRECT and unstamped, so the
                // ping-pong is bounded by the original stamp's
                // ~1 s window instead of renewing itself.
                if let window = state.windows[intended],
                    let element = eventLoop.element(
                        for: intended
                    )
                {
                    AXHelper.raise(element, pid: window.pid)
                }
            }
            updateBorders()
            updateStickyMarks()
            return
        }
        // Echo provenance (#152/#158): an echo of KiwiDesk's
        // own AX raise is not a user action. When one lands
        // after focus has already moved on in the active
        // scrolling space — a later raise, deferred or
        // forward-immediate — the echo (and the state focus
        // StateCoordinator just moved onto the echoed window)
        // would revert to the stale target. Re-assert the
        // intended focus and drop the echo. Consume the id
        // from the outstanding set either way.
        let selfEcho = outstandingSelfRaises.remove(id) != nil
        if selfEcho,
            activeSpace?.mode.defersFocusRaise == true,
            let intended = effects.focusBefore, intended != id,
            state.workspaces.space(of: id)
                == state.workspaces.activeSpace
        {
            if let space = state.workspaces.space(
                of: intended
            ) {
                state.workspaces.focus(intended, in: space)
            }
            return
        }
        // A real focus echo (a user click mid-pan) or a self
        // echo that matches the intended focus supersedes the
        // deferred raise (#143): the OS already raised whatever
        // the user reached, and a stale raise firing after the
        // pan would steal focus back.
        pendingFocusRaise = nil
        emitFocusChange(id)
        // Move the focus ring to the newly focused window.
        // Static layouts don't retile on focus (below), so
        // this is the only refresh they get; focus-driven
        // layouts retile and refresh again (cheap, idempotent).
        updateBorders()
        // Marks too: the click's raise put the window ABOVE
        // its own mark, and mark stacking is asserted only
        // on sync (never per tick) — without this the mark
        // vanished behind the window on a plain click until
        // the next retile (owner QA 2026-07-21).
        updateStickyMarks()
        // The Space Bar's focused-glyph accent follows the
        // same rule (#293): layout-independent, so it can't
        // ride the focus-driven retile alone.
        updateSpaceBar()
        // Warp only for focus changes KiwiDesk did not
        // make itself (cmd+tab, app-driven focus): a
        // self-raise already warped at intent time in
        // `focusWindow`, and an echo that moved no focus
        // (same-window re-focus) is not a change (#186).
        if !selfEcho, effects.focusBefore != id {
            warpMouseToFocused(id)
        }
        // cmd+tab (or a click) can reach a window hidden
        // in an inactive virtual space; pull that space
        // forward instead of typing into a stashed window.
        // Deferred: app activation transiently re-reports
        // the app's OLD focused window right before a new
        // window opens — only follow if focus settles.
        // A STICKY window is exempt (#414): it is visible
        // and legitimately focusable on every space, so
        // following its home would yank the user back to
        // it on every interaction — the fly-back bug.
        if let space = state.workspaces.space(of: id),
            space != state.workspaces.activeSpace,
            state.windows[id]?.isSticky != true
        {
            scheduleFocusFollow(id)
        } else if activeSpace?.mode.isFocusDriven == true {
            // A foreign STICKY focus also lands here (its
            // follow is exempt above): the retile is
            // idempotent — the fold set focus in the
            // window's home space, not this one — so it
            // costs one no-op pass. Deliberate.
            retileWithScrollDuration()
        }
        // Keep floats above the just-focused tiled window
        // (#418). Skipped on a self-echo so the raise's own
        // focus handoff cannot re-trigger it.
        if !selfEcho {
            raiseFloatsAbove(afterFocusing: id)
        }
    }

    /// Whether a same-app sibling report for `id` is inherently
    /// suspect by WHERE the window lives (#465/#496): a hidden
    /// space always is; a space shown on a display OTHER than
    /// the active space's is too (the cross-display steal — a
    /// forced activation keys the app's MRU window over there).
    /// The active space's own display stays trusted so in-app
    /// window cycling is never fought.
    private func distrustsSiblingSpace(
        of id: WindowID
    ) -> Bool {
        guard
            let echoSpace = state.workspaces.space(of: id)
        else { return false }
        guard
            state.workspaces.visibleSpaces.contains(echoSpace)
        else { return true }
        guard
            let active = state.workspaces.activeSpace,
            echoSpace != active
        else { return false }
        let activeDisplay = state.workspaces.display(of: active)
        let echoDisplay = state.workspaces.display(of: echoSpace)
        return echoDisplay != activeDisplay
    }

    /// Whether a left click landed inside `id`'s frame within
    /// the sibling-distrust window — the discriminator that
    /// tells a genuine cross-display click from an activation
    /// re-report (#496). Frames and the stamp are both AX
    /// coordinates.
    private func recentClickInside(
        _ id: WindowID,
        now: Date
    ) -> Bool {
        guard let click = lastLeftClick,
            now.timeIntervalSince(click.at)
                < Self.selfRaiseSiblingWindow,
            let frame = state.windows[id]?.frame
        else { return false }
        return frame.contains(click.point)
    }

    /// Whether a left click within the echo window actually
    /// REACHED `id` — the raise-echo revert's provenance escape
    /// (#687). Deliberately stricter than `recentClickInside`:
    /// containment alone is ambiguous here, because edge-pile
    /// frames overlap, so a slow pile-mate's late echo can
    /// contain the click point too — honoring it would pan the
    /// row onto a window the user did not click. The stacking
    /// read resolves the tie: the click reached the frontmost
    /// window at its point, and a pile-mate the drain raised
    /// after the click still cannot sit above it (a quiet raise
    /// never beats the frontmost app's key window — measured
    /// for #684). An unwired provider answers "unknown", which
    /// is no provenance — the revert then behaves as before.
    /// The containment check ahead of the provider call is a
    /// SHORT-CIRCUIT, not load-bearing (the loop re-checks it):
    /// it skips the stacking read for reports whose window the
    /// click plainly missed.
    private func recentClickReached(
        _ id: WindowID,
        now: Date
    ) -> Bool {
        guard let click = lastLeftClick,
            now.timeIntervalSince(click.at)
                < Self.zOrderRaiseEchoWindow,
            state.windows[id]?.frame.contains(click.point)
                == true,
            let stacking = stackingOrderProvider?()
        else { return false }
        for candidate in stacking {
            guard
                let frame = state.windows[candidate]?.frame,
                frame.contains(click.point)
            else { continue }
            return candidate == id
        }
        return false
    }
}
