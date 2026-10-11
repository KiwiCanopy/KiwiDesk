import Foundation

/// `gather` (#1510): every window of an app into the Space the
/// user is on. A tracked window is filed through the one
/// `fileMembership`; a window up on another macOS Desktop (#1146)
/// has its remembered Space pointed at the target and is MOVED
/// onto the Desktop that Space shows — a hop, never a switch — so
/// its arrival files it there. Nothing launches: an app with no
/// window to gather refuses.
extension KiwiCore {
    func gather(_ args: [JSONValue]) -> CommandResponse {
        guard let bundleID = args.first?.stringValue?.lowercased()
        else { return .fail("expected app bundle id") }
        guard let target = state.workspaces.activeSpace else {
            return .fail("no active Space to gather into")
        }
        let local = gatherableWindows(bundleID: bundleID, into: target)
        let hopped = hopAwayWindows(bundleID: bundleID, into: target)
        guard !local.isEmpty || hopped else {
            return .fail("no \(bundleID) window outside this Space")
        }
        for id in local {
            fileMembership(
                id,
                into: target,
                from: state.workspaces.space(of: id)
            )
        }
        onLog(
            "gather: \(bundleID) — \(local.count) window(s) filed "
                + "into space \(target.raw)"
                + (hopped ? ", away ones moved here" : "")
        )
        if !local.isEmpty { retile(animated: true) }
        return .ok()
    }

    /// The app's tracked windows outside `target`, in Space order
    /// then slot order — the Space Bar's reading order. A native
    /// fullscreen window keeps its own Space (#670), and a sticky
    /// move the #445 gate refuses stays where it is.
    func gatherableWindows(
        bundleID: String,
        into target: SpaceID
    ) -> [WindowID] {
        let landing = landingDisplay(of: target)
        return state.workspaces.allSpaces
            .filter { $0.id != target }
            .flatMap(\.windows)
            .filter { id in
                guard let window = state.windows[id],
                    window.appBundleID?.lowercased() == bundleID,
                    !window.isFullscreen
                else { return false }
                return !stickyMoveRefused(
                    id,
                    to: target,
                    landingOn: landing
                )
            }
    }

    /// Moves the app's windows that are up on an away Desktop onto
    /// the Desktop `target`'s screen shows, their remembered Space
    /// re-pointed first so each arrival files into `target`. False
    /// without the bridge, a census, or a window to move.
    private func hopAwayWindows(
        bundleID: String,
        into target: SpaceID
    ) -> Bool {
        guard canDriveDesktops,
            let reach = awayReach(bundleID: bundleID),
            !reach.windows.isEmpty,
            let uuid = state.workspaces.display(of: target)
                .flatMap(NativeSpaces.displayUUID(for:))
                ?? reach.snapshot.mainUUID,
            let shown = reach.snapshot.currentSpaces[uuid]
        else { return false }
        let windows = reach.windows.map(\.window)
        for window in windows {
            state.refileAway(of: window.id, to: target)
        }
        guard WMBridge.moveWindows(windows.map(\.id), to: shown) else {
            return false
        }
        for pid in Set(windows.map(\.pid)) {
            scheduleReachReap(pid: pid)
        }
        return true
    }
}
