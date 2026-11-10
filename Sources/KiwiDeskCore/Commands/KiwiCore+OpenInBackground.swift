import Foundation

/// `open_in_background` (#3141): opens an app without taking the
/// focus, through `launch`'s background mode (#3122). The open is
/// quiet, so its window takes no focus and no rule follow, and it
/// owes a hold: the focus the app takes anyway is handed back once,
/// within `BackgroundHolds.grace` (`KiwiCore+BackgroundHold.swift`).
/// A named Space files the app's windows there (#3152), and a named
/// Desktop sends them on at their arrival (#3153).
extension KiwiCore {
    func openInBackground(_ args: [JSONValue]) -> CommandResponse {
        guard let bundleID = args.first?.stringValue?.lowercased()
        else {
            return .fail("expected app bundle id")
        }
        // A refusal launches nothing, so the place is read first.
        var space: SpaceID?
        var desktop: QuietDesktop?
        switch backgroundPlace(args) {
        case .refused(let response): return response
        case .space(let named): space = named
        case .desktop(let named): desktop = named
        case .here: break
        }
        if hasWindow(bundleID) {
            onLog("open_in_background: \(bundleID) has a window")
            return space == nil && desktop == nil
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
        let place = (space: space, desktop: desktop)
        launchFollow.noteQuietApps([bundleID], at: now, place: place)
        launchFollow.holds.note(bundleID, at: now)
        return .ok()
    }

    private enum BackgroundPlace {
        case here
        case space(SpaceID)
        case desktop(QuietDesktop)
        case refused(CommandResponse)
    }

    /// The optional `space` and `desktop` (#3152, #3153). A Space is
    /// skipped by `null`, or by `""` ahead of a Desktop, as
    /// `move_to_desktop` skips it; with a Desktop it is that
    /// Desktop's Space, ruled on at the arrival with the window.
    private func backgroundPlace(_ args: [JSONValue]) -> BackgroundPlace {
        let hasDesktop = args.count > 2 && args[2] != .null
        var space: SpaceID?
        if args.count > 1, args[1] != .null,
            !(hasDesktop && args[1] == .string(""))
        {
            guard let raw = args[1].stringValue else {
                return .refused(.fail("expected space id"))
            }
            guard state.workspaces[SpaceID(raw)] != nil else {
                return .refused(.fail("unknown space: \(raw)"))
            }
            space = SpaceID(raw)
        }
        guard hasDesktop else { return space.map { .space($0) } ?? .here }
        switch resolveDesktopArgument([args[2]]) {
        case .refused(let response):
            return .refused(response)
        case .target:
            return .desktop(
                QuietDesktop(
                    number: args[2].intValue ?? 0,
                    space: space?.raw
                )
            )
        }
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
