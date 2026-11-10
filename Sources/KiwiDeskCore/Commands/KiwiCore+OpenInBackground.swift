import Foundation

/// `open_in_background` (#3141): opens an app without taking the
/// focus, through `launch`'s background mode (#3122). The open is
/// quiet, so its window takes no focus and no rule follow, and it
/// owes a hold: the focus the app takes anyway is handed back once,
/// within `BackgroundHolds.grace` (`KiwiCore+BackgroundHold.swift`).
extension KiwiCore {
    func openInBackground(_ args: [JSONValue]) -> CommandResponse {
        guard let bundleID = args.first?.stringValue?.lowercased()
        else {
            return .fail("expected app bundle id")
        }
        // Tracked state first: a slow or failed AX list reads empty.
        if hasTrackedWindow(app: bundleID) {
            onLog("open_in_background: \(bundleID) has a window")
            return .ok()
        }
        if let pid = openOrFocus.runningAppPID(bundleID),
            !isWindowless(
                bundleID,
                census: openOrFocus.census(pid),
                reach: awayReach(bundleID: bundleID)
            )
        {
            onLog("open_in_background: \(bundleID) has a window")
            return .ok()
        }
        guard launchInBackground(bundleID) else {
            return .fail("app not found: \(bundleID)")
        }
        let now = wallClock()
        launchFollow.noteQuietApps([bundleID], at: now)
        launchFollow.holds.note(bundleID, at: now)
        return .ok()
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
