import Foundation

/// `open_in_background` (#3141): opens an app without taking the
/// focus, through `launch`'s background mode (#3122). The open is
/// quiet, so its window takes no focus and no rule follow, and it
/// owes a hold: the focus the app takes anyway is handed back once,
/// within `BackgroundHolds.grace` (`KiwiCore+BackgroundHold.swift`).
/// A named Space files the app's windows there (#3152).
extension KiwiCore {
    func openInBackground(_ args: [JSONValue]) -> CommandResponse {
        guard let bundleID = args.first?.stringValue?.lowercased()
        else {
            return .fail("expected app bundle id")
        }
        // A refusal launches nothing, so the Space is read first.
        var space: SpaceID?
        if args.count > 1, args[1] != .null {
            guard let raw = args[1].stringValue else {
                return .fail("expected space id")
            }
            guard state.workspaces[SpaceID(raw)] != nil else {
                return .fail("unknown space: \(raw)")
            }
            space = SpaceID(raw)
        }
        if hasWindow(bundleID) {
            onLog("open_in_background: \(bundleID) has a window")
            return space == nil
                ? .ok()
                : .fail(
                    "An app that already has a window is not opened "
                        + "again, so nothing was opened or moved."
                )
        }
        guard launchInBackground(bundleID) else {
            return .fail("app not found: \(bundleID)")
        }
        let now = wallClock()
        launchFollow.noteQuietApps([bundleID], at: now, into: space)
        launchFollow.holds.note(bundleID, at: now)
        return .ok()
    }

    /// A window tracked, or in the running app's own list: tracked
    /// state first, since a slow or failed AX list reads empty.
    private func hasWindow(_ bundleID: String) -> Bool {
        if hasTrackedWindow(app: bundleID) { return true }
        guard let pid = openOrFocus.runningAppPID(bundleID) else {
            return false
        }
        return !isWindowless(
            bundleID,
            census: openOrFocus.census(pid),
            reach: awayReach(bundleID: bundleID)
        )
    }
}
