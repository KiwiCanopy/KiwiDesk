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
        let now = Date()
        // Dismissing an ignored panel (Ghostty's quick
        // terminal) leaves the app frontmost and makes AX
        // re-report its managed main window — which may live
        // on another space — as focused. Following that
        // stale report switches spaces, or in a focus-driven
        // layout yanks focus to the main window on the
        // active space. The panel was flagged active while
        // it held focus (#21); consume the flag here and
        // restore the pre-panel focus instead of acting on
        // the report (#244). The flag survives a short
        // dismissal GRACE against a same-app-resigned focus
        // report, rather than clearing synchronously, because
        // live capture showed the panel app's stale re-report
        // winning that race by 125-200 ms (#951) —
        // `shouldConsumeIgnoredPanelReport` owns the state
        // machine and the click-provenance escape.
        if let pid = state.windows[id]?.pid,
            shouldConsumeIgnoredPanelReport(
                pid: pid,
                id: id,
                now: now
            )
        {
            onLog(
                "focus: w\(id.raw) re-report consumed "
                    + "(ignored-panel dismiss, pid "
                    + "\(pid)); restoring "
                    + describe(effects.focusBefore)
            )
            // The id's self-raise stamp stays: age bounds it,
            // and the #465 order read needs it as the newer
            // sibling against the app's next re-report.
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
        // Never for an echo of our OWN focus raise that is NEWER
        // than the z-order stamp (`selfRaiseVetoesRevert`): a
        // keyboard focus can land on a window a pile restore
        // stamped moments earlier, and for a tiled-sticky
        // traveler `focusBefore` stays on the stale local slot,
        // so `intended != id` cannot clear it — the revert would
        // strand the ring off the truly focused window (#431).
        // Newer only: an older or stale self stamp must not
        // veto, or the restore's own echo threads both nets —
        // vetoed here, no self-echo below, honored (#689/#887).
        //
        // Nor for a report with CLICK provenance (#687): a
        // restore's echoes come from windows the user did not
        // click, so a fresh click that reached the reported
        // window is proof no echo can forge. The revert itself
        // stays state-only either way: OS focus during a
        // sequence is owned by its closing re-assert
        // (`performZOrderSequence`), and re-asserting per echo
        // would fight the drain — docs/design-decisions.md.
        // The stamp is NOT consumed — it expires by age: lazy
        // apps re-report a raised window a second time hundreds
        // of ms after the first echo, and consume-on-first
        // honored that duplicate as deliberate focus (#689).
        // Only a clickless app/cmd-tab focus inside the window
        // is eaten, the documented trade.
        if let stamp = zOrderRaiseEchoes[id],
            now.timeIntervalSince(stamp)
                < Self.zOrderRaiseEchoWindow,
            let intended = effects.focusBefore, intended != id,
            !selfRaiseVetoesRevert(id, now: now),
            !recentClickReached(id, now: now)
        {
            onLog(
                "focus: w\(id.raw) z-order echo reverted "
                    + "to w\(intended.raw)"
            )
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
        // The echo of our OWN raise of `id` is exempt: a stamp
        // is never consumed (#887), so "not raised by us" is
        // read as ORDER — the sibling's raise must be the newer
        // one (`siblingRaiseOutranks`), or a step A→B within
        // the window would distrust B's own echo.
        if state.windows[id]?.isSticky != true,
            siblingRaiseOutranks(id, now: now),
            distrustsSiblingSpace(of: id),
            !recentClickInside(id, now: now)
        {
            onLog(
                "focus: w\(id.raw) sibling re-report "
                    + "distrusted; re-asserting "
                    + describe(effects.focusBefore)
            )
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
        // intended focus and drop the echo.
        // Age-bounded — an already-key raise never echoes, so an
        // unbounded entry ate the next click (#687) — and NOT
        // consumed: a lazy app's duplicate report lands after
        // the user's next step (#887, docs/design-decisions.md).
        let selfEcho = freshSelfRaise(id, now: now)
        // And even a FRESH entry stands down for a report with
        // click provenance (#687): a click that reached the
        // reported window is a user action our raise cannot
        // have forged — without this, a click landing inside
        // the ~1 s echo window of a no-echo re-assert was
        // still eaten. Safe against bar clicks forging it:
        // a press a bar absorbed resolves no window at all
        // (`clickReachedWindow`).
        if selfEcho,
            activeSpace?.mode.defersFocusRaise == true,
            let intended = effects.focusBefore, intended != id,
            state.workspaces.space(of: id)
                == state.workspaces.activeSpace,
            !recentClickReached(id, now: now)
        {
            onLog(
                "focus: w\(id.raw) self-echo dropped; "
                    + "keeping w\(intended.raw)"
            )
            if let space = state.workspaces.space(
                of: intended
            ) {
                state.workspaces.focus(intended, in: space)
            }
            return
        }
        // The accessibility-steal return (#958): LAST among
        // the consumes — a report an earlier machine claims is
        // our raises' fallout must not spend the one-shot debt
        // — AND gated on `!selfEcho`, because a stamped
        // self-raise echo can fall PAST the drop block above
        // (a non-defer layout, or `intended == id`) while
        // still being our own fallout, not macOS's misdirected
        // yield (re-review, 2026-08-27). The rest is
        // `returnAccessibilitySteal`'s.
        if !selfEcho,
            returnAccessibilitySteal(id: id, now: now)
        {
            return
        }
        // A real focus echo (a user click mid-pan) or a self
        // echo that matches the intended focus supersedes the
        // deferred raise (#143): the OS already raised whatever
        // the user reached, and a stale raise firing after the
        // pan would steal focus back.
        pendingFocusRaise = nil
        // State and the OS agree again (#1130).
        disarmWakeFocusHeal()
        let honoredApp: String =
            state.windows[id]?.appName ?? "?"
        let honoredBefore: String = describe(
            effects.focusBefore
        )
        onLog(
            "focus: w\(id.raw) (\(honoredApp)) honored; "
                + "before \(honoredBefore), "
                + "selfEcho=\(selfEcho)"
        )
        rememberHonoredFocus(id)
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
        // A report with CLICK provenance is mouse-made focus
        // and needs no warp — the pointer is exactly where
        // the user put it. The fire-time inside check cannot
        // cover this: in a focus-driven layout the click PANS
        // the row, so the clicked window's settled slot slides
        // out from under the cursor and the "warp" yanks the
        // pointer after it (#689 device QA — pre-#689 that
        // warp was dropped by the in-flight hold; the re-fire
        // surfaced it).
        if !selfEcho, effects.focusBefore != id,
            !recentClickReached(id, now: Date())
        {
            warpMouseToFocused(id)
        }
        // cmd+tab (or a click) can reach a window hidden
        // in an inactive Space; pull that space
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
}
