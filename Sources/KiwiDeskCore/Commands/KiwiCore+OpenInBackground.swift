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
        let place: QuietPlace
        switch backgroundPlace(args) {
        case .refused(let response): return response
        case .place(let read): place = read
        }
        if hasWindow(bundleID) {
            onLog("open_in_background: \(bundleID) has a window")
            return place == .here
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
        launchFollow.noteQuietApps([bundleID], at: now, place: place)
        launchFollow.holds.note(bundleID, at: now)
        return .ok()
    }

    private enum PlaceReading {
        case place(QuietPlace)
        case refused(CommandResponse)
    }

    /// The optional `space` and `desktop` (#3152, #3153). A Space is
    /// skipped by `null`, or by `""` ahead of a Desktop, as
    /// `move_to_desktop` skips it. With a Desktop, a Space need not
    /// exist yet, as there (#1150), and every check that needs no
    /// window is asked now; a Desktop already shown is refused, since
    /// its Space can be named instead.
    private func backgroundPlace(_ args: [JSONValue]) -> PlaceReading {
        let hasDesktop = args.count > 2 && args[2] != .null
        var raw: String?
        if args.count > 1, args[1] != .null,
            !(hasDesktop && args[1] == .string(""))
        {
            guard let read = args[1].stringValue, !read.isEmpty else {
                return .refused(.fail("expected space id"))
            }
            raw = read
        }
        guard hasDesktop else {
            guard let raw else { return .place(.here) }
            guard state.workspaces[SpaceID(raw)] != nil else {
                return .refused(.fail("unknown space: \(raw)"))
            }
            return .place(.space(SpaceID(raw)))
        }
        switch resolveDesktopArgument([args[2]]) {
        case .refused(let response):
            return .refused(response)
        case .target(let target):
            guard !target.isCurrent else {
                return .refused(
                    .fail(
                        "That Desktop is already showing, so name its "
                            + "Space instead."
                    )
                )
            }
            if let raw, let refusal = spaceLandingRefusal(raw, for: target) {
                return .refused(refusal)
            }
            return .place(
                .desktop(
                    QuietDesktop(
                        id: target.space,
                        space: raw.map { SpaceID($0) }
                    )
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
