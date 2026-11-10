import Foundation

/// `open_in_background` (#3141): opens an app without taking the
/// focus, through `launch`'s background mode (#3122). The open is
/// quiet, so its window takes no focus and no rule follow, and it
/// owes one hand-back: an app that takes the focus anyway gives
/// it back once, through the command path, within
/// `LaunchFollowIntent.holdGrace`. A second take is the app's.
extension KiwiCore {
    func openInBackground(_ args: [JSONValue]) -> CommandResponse {
        guard let bundleID = args.first?.stringValue?.lowercased()
        else {
            return .fail("expected app bundle id")
        }
        // A window up, parked or away: nothing to open.
        if hasWindow(app: bundleID) || runningAppShowsWindow(bundleID) {
            onLog("open_in_background: \(bundleID) has a window")
            return .ok()
        }
        guard launchInBackground(bundleID) else {
            return .fail("app not found: \(bundleID)")
        }
        let now = wallClock()
        launchFollow.noteQuietApps([bundleID], at: now)
        let focus = focusedWindowID
        oweLaunchFollow(
            quietly: LaunchFollowIntent.QuietOpen(
                bundleIDs: [bundleID],
                purpose: .hold,
                focus: focus,
                front: focus.flatMap { state.windows[$0]?.appBundleID }?
                    .lowercased(),
                at: now
            )
        )
        return .ok()
    }

    /// Whether the running app's own AX list holds a window, up or
    /// minimized: one KiwiDesk does not track (an ignored or
    /// unadopted one) still needs no opening.
    private func runningAppShowsWindow(_ bundleID: String) -> Bool {
        guard let pid = openOrFocus.runningAppPID(bundleID) else {
            return false
        }
        let census = openOrFocus.census(pid)
        return census.visible > 0 || !census.minimized.isEmpty
    }

    /// Whether `app` (a list key) has a window: one KiwiDesk tracks
    /// (the pocket's included, in either phase), one minimized, or
    /// one on another Desktop. A tracked-state read, never a census;
    /// a ⌘H-hidden app's windows are in none of the three.
    func hasWindow(app: String) -> Bool {
        func key(_ bundleID: String?, _ name: String) -> String {
            AppRef(bundleID: bundleID, name: name).listKey
        }
        return state.windows.all.contains { $0.appRef.listKey == app }
            || state.minimizeOrder.contains { key($0.bundleID, $0.app) == app }
            || state.awayWindows.values.contains {
                key($0.appBundleID, $0.appName) == app
            }
    }

    /// The `handleWindowFocused` arm of the hold: a report moving
    /// the focus onto a window of an app opened in the background,
    /// off another app's window, hands it back to that window, once
    /// per app and by command, so its own report arrives intended
    /// (#1281). A click on the window is the user's choice and
    /// spends the hold unpaid. True where it handed back.
    func handBackBackgroundFocus(
        _ id: WindowID,
        before: WindowID?,
        now: Date
    ) -> Bool {
        guard let app = state.windows[id]?.appRef.listKey,
            let before, before != id,
            let left = state.windows[before]?.appRef.listKey, left != app,
            launchFollow.claimHold(app, at: now)
        else { return false }
        guard !recentClickReached(id, now: now),
            focusWindow(before, refocusRetile: false, warp: false, leaving: id)
        else {
            onLog("open_in_background: w\(id.raw) keeps the focus")
            return false
        }
        onLog(
            "open_in_background: w\(id.raw) took the focus — "
                + "handed back to w\(before.raw)"
        )
        return true
    }
}
