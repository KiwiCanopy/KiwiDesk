import Foundation

/// `move_here` (#1513): ONE window of an app — its most recently
/// focused — into the Space the user is on, focused, through
/// Jump to window's `moveHere(_:)` (#1875). `gather` is the
/// all-windows verb (#1510). An app with no window takes Open or
/// Focus's path, which reopens or launches it.
extension KiwiCore {
    func moveHereCommand(_ args: [JSONValue]) -> CommandResponse {
        guard let bundleID = args.first?.stringValue?.lowercased()
        else { return .fail("expected app bundle id") }
        guard state.workspaces.activeSpace != nil else {
            return .fail("no active Space to move into")
        }
        guard let id = moveHereWindow(bundleID: bundleID) else {
            return launch([.string(bundleID)], newInstance: false)
        }
        onLog("move_here: \(bundleID) — w\(id.raw)")
        guard moveHere(.window(id)) else {
            return .fail("could not move the \(bundleID) window here")
        }
        return .ok()
    }

    /// The app's most recently focused window — tracked, up on an
    /// away Desktop, or minimized. With no focus on record yet (a
    /// fresh KiwiDesk), the app's own focused window, else the
    /// first tracked one in Space order, else an away one, else
    /// the last minimized.
    func moveHereWindow(bundleID: String) -> WindowID? {
        let tracked = state.workspaces.allSpaces
            .flatMap(\.windows)
            .filter { id in
                guard let window = state.windows[id] else { return false }
                return window.appBundleID?.lowercased() == bundleID
                    && !window.isTransientOverlay
            }
        let away = awayWindows(bundleID: bundleID)
            .filter(\.isUp).map(\.id)
        let known = jump.knownWindows()
        let minimized = state.minimizeOrder.reversed()
            .filter { record in
                record.bundleID?.lowercased() == bundleID
                    && (known.map { $0.contains(record.id) } ?? true)
            }
            .map(\.id)
        let all = tracked + away + minimized
        if let recent = all.max(by: {
            state.focusRecencyRank(of: $0)
                < state.focusRecencyRank(of: $1)
        }), state.focusRecencyRank(of: recent) > 0 {
            return recent
        }
        if let pid = tracked.first.flatMap({ state.windows[$0]?.pid }),
            let own = eventLoop.focusedWindowID(pid: pid),
            tracked.contains(own)
        {
            return own
        }
        return all.first
    }
}
