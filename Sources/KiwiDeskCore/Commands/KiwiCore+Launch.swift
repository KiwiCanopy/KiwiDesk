import Foundation

/// `focus_or_spawn` / `spawn_new` (#637, #673, #1146): the cycle,
/// the reach onto an away Desktop, the one un-park, the activate
/// and the launch — split from `KiwiCore+Commands.swift` at the
/// §2.1 ceiling. Every machine touch goes through `openOrFocus`
/// and the reach's bridge seam.
extension KiwiCore {
    func launch(
        _ args: [JSONValue],
        newInstance: Bool
    ) -> CommandResponse {
        guard
            let bundleID = args.first?.stringValue?.lowercased()
        else {
            return .fail("expected app bundle id")
        }
        // Already focused: advance to the app's next window
        // (#637) — checked first, off tracked state alone, so
        // the repeat press cycles instead of re-activating.
        if !newInstance,
            cycleAppWindow(
                bundleID: bundleID,
                direction: .next,
                verb: "focus_or_spawn"
            ) == .stepped
        {
            return .ok()
        }
        // Pull an existing instance forward, matched by bundle
        // id (locale- and rename-proof, unlike the display
        // name — see AppRef). Through `openOrFocus`, whose four
        // seams are this branch's every touch of the machine.
        if !newInstance,
            let pid = openOrFocus.runningAppPID(bundleID)
        {
            // A tracked window is focused by command, its Space
            // switched to: the one it was last focused in (#1840).
            if pullRecentWindow(bundleID: bundleID, pid: pid) {
                return .ok()
            }
            let census = openOrFocus.census(pid)
            // Nothing up here but a window up on an away Desktop
            // (#1146): reach it rather than un-park or duplicate.
            // The reach owes the focus at the arrival; a refused
            // or absent bridge falls through to the activate. Read
            // only where nothing is up here — the un-park below
            // runs only there too.
            let reach =
                census.visible == 0 ? awayReach(bundleID: bundleID) : nil
            if let reach, let first = reach.windows.first,
                reachAwayWindow(
                    first.window,
                    desktop: first.desktop,
                    snapshot: reach.snapshot,
                    verb: "focus_or_spawn"
                )
            {
                return .ok()
            }
            // `activate` does not deminiaturize, so an app with
            // nothing on screen came forward showing nothing at
            // all (#673). Restore one first — BEFORE the
            // activate, so the app comes forward with a window
            // already on its way up rather than a beat behind —
            // and leave the rest parked. Which one, and why only
            // one, is argued in `KiwiCore+LaunchRestore.swift`.
            // A window UP on an away Desktop counts as up, so
            // nothing is un-parked beside it (#1146).
            if reach?.windows.isEmpty ?? true {
                restoreOneMinimizedIfNothingVisible(
                    pid: pid,
                    bundleID: bundleID,
                    census: census
                )
            }
            // Only an app with nothing up here opens a window for
            // this pull; one already showing is merely focused.
            if census.visible == 0 { oweLaunchFollow(bundleID) }
            // Nothing to pull — no window up, parked or on record
            // away: the app outlived its last window (Safari after
            // its ✕). `activate` asks for no window, so reopen it
            // the way a Dock click does (#1840). An away entry an
            // unreadable census could not confirm keeps the
            // activate; one the census no longer lists does not.
            if isWindowless(bundleID, census: census, reach: reach),
                openOrFocus.openApp(bundleID, .reopen)
            {
                return .ok()
            }
            openOrFocus.activate(pid)
            return .ok()
        }
        // Not running (or `newInstance`): LaunchServices resolves
        // the bundle id to its install location — finding apps the
        // old /Applications path scan missed (Finder in
        // CoreServices, apps in ~/Applications). Seamed like the
        // branch above, so no test can launch a real app by naming
        // one that happens to be installed.
        let mode: OpenAppMode = newInstance ? .newInstance : .reopen
        guard openOrFocus.openApp(bundleID, mode) else {
            return .fail("app not found: \(bundleID)")
        }
        // The user named the app: its next rule-placed window
        // takes them along, whatever the press timing (#1599).
        oweLaunchFollow(bundleID)
        return .ok()
    }

    /// `launch`'s background mode (#3122): opens `bundleID` — a
    /// launch, or a reopen of a running app with no window —
    /// without activating it, owing no follow and reaching no away
    /// Desktop. The caller judged the app windowless. False where
    /// LaunchServices cannot resolve the id.
    func launchInBackground(_ bundleID: String) -> Bool {
        openOrFocus.openApp(bundleID.lowercased(), .background)
    }

    /// Whether a running app has no window to show: none up or
    /// minimized in its own list, and none on record on an away
    /// Desktop that `reach` (read only past the census) does not
    /// rule out. The one test Open or Focus's reopen (#1840) and
    /// `open_in_background` take.
    func isWindowless(
        _ bundleID: String,
        census: AppWindowCensus,
        reach: @autoclosure () -> AwayReach?
    ) -> Bool {
        guard census.visible == 0, census.minimized.isEmpty else {
            return false
        }
        let away =
            reach()?.listsAny ?? !awayWindows(bundleID: bundleID).isEmpty
        return !away
    }
}
