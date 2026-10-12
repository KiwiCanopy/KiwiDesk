import Foundation

/// `move_here` (#1513): ONE window of an app — the one Open or
/// Focus would land on (#1840) — into the Space the user is on,
/// focused, through Jump to window's `moveHere(_:)` (#1875).
/// `gather` is the all-windows verb (#1510). A hidden app is
/// unhidden, as the panel's Move here on its row is; an app with
/// no window takes Open or Focus's path, which reopens or
/// launches it.
extension KiwiCore {
    func moveHereCommand(_ args: [JSONValue]) -> CommandResponse {
        guard let bundleID = args.first?.stringValue?.lowercased()
        else { return .fail("expected app bundle id") }
        guard let active = state.workspaces.activeSpace else {
            return .fail("no active Space to move into")
        }
        let pid = openOrFocus.runningAppPID(bundleID)
        guard
            let id = moveHereWindow(bundleID: bundleID, into: active)
        else {
            // A hidden app's windows are not in state (#913).
            if let pid, eventLoop.appIsHidden(pid) {
                moveHere(.hiddenApp(pid))
                return .ok()
            }
            return launch([.string(bundleID)], newInstance: false)
        }
        onLog("move_here: \(bundleID) — w\(id.raw)")
        guard moveHere(.window(id)) else {
            return .fail("could not move the \(bundleID) window here")
        }
        return .ok()
    }

    /// The app's window a press means, among those Move here can
    /// take: tracked and away in ring order — a full-screen one,
    /// one the sticky gate keeps elsewhere and, without the
    /// Desktop bridge, an away one left out — then the minimized
    /// ones, latest first.
    func moveHereWindow(
        bundleID: String,
        into active: SpaceID
    ) -> WindowID? {
        let away =
            canDriveDesktops
            ? Set(awayWindows(bundleID: bundleID).filter(\.isUp).map(\.id))
            : []
        let ring = cycleRing(bundleID: bundleID, away: away)
            .filter { id in
                guard let window = state.windows[id] else {
                    return away.contains(id)
                }
                return !window.isFullscreen
                    && !stickyHoldsElsewhere(id, from: active)
            }
        let known = jump.knownWindows()
        let minimized = state.minimizeOrder.reversed()
            .filter { record in
                record.bundleID?.lowercased() == bundleID
                    && (known.map { $0.contains(record.id) } ?? true)
            }
            .map(\.id)
        let pid =
            openOrFocus.runningAppPID(bundleID)
            ?? ring.first.flatMap { state.windows[$0]?.pid }
        return mostRecentWindow(of: ring + minimized, pid: pid)
    }

    /// A sticky window the gate refuses to move into `active` —
    /// never a ∞ one, which is already drawn here.
    private func stickyHoldsElsewhere(
        _ id: WindowID,
        from active: SpaceID
    ) -> Bool {
        guard let block = stickyMoveBlock(id, to: active) else {
            return false
        }
        return !(block == .global && state.windows[id]?.stickyScope == .global)
    }
}
