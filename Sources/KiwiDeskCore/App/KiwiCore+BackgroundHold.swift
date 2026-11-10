import Foundation

/// The hand-back an `open_in_background` owes (#3141 ▸ Ruling): an
/// app opened behind the focus that takes it anyway gives it back
/// once, by command, so the hand-back reports as intended (#1281).
/// Two doors share each app's one claim, since either can come
/// first: the app's activation, which fires before its first window
/// is adopted (#1599 measured the heal 0.6–6.3 s late), and the
/// focus report of a window already tracked. A second take is the
/// app's: its windows leave the #1161 ledger, so no placement
/// bounce re-asserts against it.
extension KiwiCore {
    /// The `handleWindowFocused` door: a report moving the focus off
    /// another app's window onto a held app's. A click on the window
    /// is the user's choice and spends the hold unpaid. True where
    /// it handed back.
    func handBackBackgroundFocus(
        _ id: WindowID,
        before: WindowID?,
        now: Date
    ) -> Bool {
        guard let app = state.windows[id]?.appRef.listKey,
            let before, before != id,
            let left = state.windows[before]?.appRef.listKey, left != app,
            launchFollow.holds.claim(app, at: now)
        else { return false }
        guard !recentClickReached(id, now: now),
            handBack(to: before, from: app, leaving: id)
        else {
            onLog("open_in_background: w\(id.raw) keeps the focus")
            return false
        }
        return true
    }

    /// The `noteAppActivation` door: a held app coming forward while
    /// another app's window holds the focus. A click within
    /// `pressGrace` that did not land in that window (the Dock, the
    /// app's own window) or a raise of ours is a choice of the app,
    /// and spends the hold unpaid.
    func handBackBackgroundActivation(
        _ activation: AppActivation,
        now: Date
    ) {
        guard let app = activation.bundleID?.lowercased(),
            let focus = focusedWindowID,
            let left = state.windows[focus]?.appRef.listKey, left != app,
            launchFollow.holds.claim(app, at: now)
        else { return }
        let clicked =
            lastLeftClick.map {
                now.timeIntervalSince($0.at) < LaunchFollowIntent.pressGrace
                    && $0.reached != focus
            } ?? false
        let ours = state.windows.all.contains {
            $0.appRef.listKey == app && freshSelfRaise($0.id, now: now)
        }
        guard !clicked, !ours,
            handBack(to: focus, from: app, leaving: nil)
        else {
            onLog("open_in_background: \(app) keeps the focus")
            return
        }
    }

    /// Focuses `target` again off `app`, and drops the app's windows
    /// from the #1161 ledger so its next take is honored.
    private func handBack(
        to target: WindowID,
        from app: String,
        leaving: WindowID?
    ) -> Bool {
        guard
            focusWindow(
                target,
                refocusRetile: false,
                warp: false,
                leaving: leaving
            )
        else { return false }
        for window in state.windows.all where window.appRef.listKey == app {
            tiler.placements.forget(window.id)
        }
        onLog(
            "open_in_background: \(app) took the focus — handed back "
                + "to w\(target.raw)"
        )
        return true
    }
}
