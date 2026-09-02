import Foundation

/// `pull_or_spawn` / `spawn_new` (#637, #673, #1146): the cycle,
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
            cycleToNextWindow(bundleID: bundleID)
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
                    verb: "pull_or_spawn"
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
            openOrFocus.activate(pid)
            return .ok()
        }
        // Not running (or `newInstance`): LaunchServices resolves
        // the bundle id to its install location — finding apps the
        // old /Applications path scan missed (Finder in
        // CoreServices, apps in ~/Applications). Seamed like the
        // branch above, so no test can launch a real app by naming
        // one that happens to be installed.
        guard openOrFocus.openApp(bundleID, newInstance) else {
            return .fail("app not found: \(bundleID)")
        }
        return .ok()
    }
}
