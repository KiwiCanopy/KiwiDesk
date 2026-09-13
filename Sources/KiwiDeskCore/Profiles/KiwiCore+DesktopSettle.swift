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
    /// task either no-op'd on the staleness guard or
    /// (switch away and back inside the delay) fired an early
    /// settle mid-reconcile — and `stop()` can now cancel it.
    ///
    /// **Carries the native Space id, never a `DesktopKey`**
    /// (#1230). A key is re-keyed at any mint — a monitor
    /// change or `bind_profile_to_desktop`, not only a switch —
    /// so a settle scheduled under `.number(n)` for a
    /// just-stamped Desktop would compare against
    /// `.identity(x)` 600 ms later and stand the WHOLE settle
    /// down: the arrival sweep, the sticky re-carry, the away
    /// census re-arm, the retile, the z-order restore and the
    /// refocus. The native id names the same Desktop under both
    /// spellings and never moves.
    func settleAfterDesktopSwitch(_ desktop: SkyLight.SpaceID?) {
        deferred.schedule(
            .desktopSettle,
            after: .milliseconds(600)
        ) { [weak self] in
            self?.desktopSettle(ifStill: desktop)
        }
    }

    /// The settle body, split out so tests can fire it without
    /// waiting out the 600 ms schedule.
    ///
    /// Compared against `desktopMemory.lastDesktopSpace` rather than
    /// `lastDesktop`, for the re-key reason above — core-owned,
    /// so this reads no machine state.
    func desktopSettle(ifStill desktop: SkyLight.SpaceID?) {
        guard desktopMemory.lastDesktopSpace == desktop else { return }
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
            departedWithThisSwitch(focused)
        {
            // A focus the switch itself removed was re-listed,
            // not chosen; raising it pulls the user back (#1364).
            onLog(
                "desktop settle: w\(focused.raw) left with this "
                    + "switch and came back — refocus stands down "
                    + "(#1364)"
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

    /// How long a filed departure is kept: the settle that reads
    /// one runs within the switch grace plus 600 ms, so this only
    /// prunes entries no switch followed — a drag's vanish, a
    /// slow app's trailing destroy — on the same measurement
    /// `desktopMoveDepartureWindow` prices (#1364).
    static var switchDepartureWindow: TimeInterval {
        desktopMoveDepartureWindow
    }

    /// The one FILING door of `DesktopMemory.switchDepartures`
    /// (#1364): a departure `departedWithDesktop` reported. The
    /// re-key, the retire and the #634 forget are the record's
    /// other writers, beside `honoredFocus`'s.
    func fileSwitchDeparture(_ id: WindowID, now: Date = Date()) {
        desktopMemory.switchDepartures =
            desktopMemory.switchDepartures.filter {
                now.timeIntervalSince($0.value)
                    < Self.switchDepartureWindow
            }
        desktopMemory.switchDepartures[id] = now
    }

    /// Whether `id` LEFT WITH ITS DESKTOP in the switch being
    /// settled: filed no earlier than the switch grace before the
    /// switch, since an app's own destroy beats the notification
    /// (#1364). The residue — a departure inside that grace
    /// before a switch it did not belong to — is priced in the
    /// design-decisions entry.
    func departedWithThisSwitch(_ id: WindowID) -> Bool {
        guard let filed = desktopMemory.switchDepartures[id]
        else { return false }
        let since = lastDesktopSwitch.addingTimeInterval(
            -EventLoop.spaceSwitchCoalesceGrace
        )
        return filed >= since
    }
}
