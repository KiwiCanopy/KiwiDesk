import Foundation

/// What a Desktop switch owes 600 ms later — split from
/// `KiwiCore+Desktops.swift` at the §2.1 ceiling along its own
/// subject seam: that file decides what a switch DOES, this one
/// what the settle re-asserts once the AX reconcile has
/// re-tracked the arrived windows.
extension KiwiCore {
    /// The post-switch AX reconcile re-tracks this desktop's
    /// windows over the next few hundred ms; afterwards,
    /// re-assert the layout (stashing included) and hand
    /// focus to the restored space — the OS may have focused
    /// a stashed window during the transition. Keyed (#49):
    /// rapid switches keep only the latest settle — a stale
    /// task either no-op'd on the `lastDesktop` guard or
    /// (switch away and back inside the delay) fired an early
    /// settle mid-reconcile — and `stop()` can now cancel it.
    func settleAfterDesktopSwitch(_ desktop: DesktopKey?) {
        deferred.schedule(
            .desktopSettle,
            after: .milliseconds(600)
        ) { [weak self] in
            self?.desktopSettle(ifStill: desktop)
        }
    }

    /// The settle body, split out so tests can fire it without
    /// waiting out the 600 ms schedule.
    func desktopSettle(ifStill desktop: DesktopKey?) {
        guard lastDesktop == desktop else { return }
        // The switch's `reconcileAll` is census-gated (#1037),
        // and that census can beat the compositor: a window
        // still landing when the notification fired was on no
        // list, so its app was skipped. Sweep the arrivals now
        // — before the retile below, which then places them.
        eventLoop.reconcileOnScreenArrivals()
        // #1145: carry again once the switch has settled —
        // idempotent, and the net under the eager carry in
        // `handleDesktopChange`.
        refreshStickyReach()
        // #1146: a window closed while its Desktop was away; the
        // settle also re-arms the cadence a failed read disarmed.
        if refreshAwayWindows() { scheduleAwayCensus() }
        // A fullscreen/system space: the retile, z-order
        // restore and refocus stand down (#670) — the refocus
        // would AX-raise the desktop's focused window behind
        // the fullscreen app. The bars must still sync: the
        // panels join every Space by construction, the switch
        // handler skipped its retile on the nil number, so
        // this sync is what retires them (review 2026-08-03).
        guard NativeSpaces.activeSpaceIsUser() else {
            updateAppBar()
            updateSpaceBar()
            return
        }
        retile(animated: false, force: true)
        // The switch rebuilt this desktop's windows with
        // arbitrary stacking; put the overlapping
        // layouts' z-order back before handing focus over.
        scheduleZOrderRestore()
        // #1207: a return still owing its focus to a window not
        // yet re-listed stands this refocus down — raising
        // `Space.focused` here is the first-in-row jump.
        if let owed = desktopMemory.returnFocus.owed() {
            onLog(
                "desktop return: focus owed to w\(owed.raw), "
                    + "settle refocus stands down"
            )
        } else if let focused = activeSpace?.focused,
            state.windows[focused]?.isFullscreen != true
        {
            // The instant retile above already placed the
            // windows; re-tiling on focus would fly them
            // from stale frames (issue #11). A fullscreen
            // window can still hold the focused slot (the
            // fold never clears it, #670 review) — raising
            // it would switch the user to its Space, so it
            // is the one focus this settle never re-asserts.
            focusWindow(
                focused,
                refocusRetile: false,
                warp: true
            )
        }
    }
}
