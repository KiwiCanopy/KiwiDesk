import Foundation

/// Minimize order (#673). Open or Focus restores one window when
/// every window of the app is minimized, and "one" means the most
/// recently minimized — the Dock's own precedent for clicking an
/// app icon.
///
/// `minimizedWindows` cannot answer that: it is an unordered
/// `Set<WindowID>`, and by the time a restore asks, the window
/// snapshot carrying the bundle id has been erased by the same
/// fold that filed the id. So the order and the owner are
/// recorded here, at the minimize, while both are still readable.
extension StateCoordinator {
    /// One minimized window, as much of it as outlives the
    /// snapshot. `id` is a `var` so a native-tab re-key can swap
    /// it in place like every other id-keyed container (#308).
    struct MinimizedWindow: Sendable {
        var id: WindowID
        let pid: pid_t
        /// Lowercased at record time: every consumer matches
        /// against the command's already-lowercased bundle id.
        let bundleID: String?
    }

    /// Files a minimize, newest last. Call while the window
    /// snapshot is still live — the destroy fold erases it a few
    /// lines later.
    ///
    /// Staleness matches `minimizedWindows`: a window closed
    /// while minimized fires no event, so its entry lingers for
    /// the session. Harmless here — a restore that cannot find
    /// the remembered id among the app's live minimized windows
    /// falls back to the first one AX lists.
    mutating func rememberMinimized(_ id: WindowID) {
        guard let window = windows[id] else { return }
        minimizeOrder.removeAll { $0.id == id }
        minimizeOrder.append(
            MinimizedWindow(
                id: id,
                pid: window.pid,
                bundleID: window.appBundleID?.lowercased()
            )
        )
    }

    /// Drops a window's minimize record — it came back, or its
    /// app went away. Called on every `.windowCreated` (a
    /// deminiaturize is one) and on `.appTerminated`.
    mutating func forgetMinimized(_ id: WindowID) {
        minimizeOrder.removeAll { $0.id == id }
    }

    mutating func forgetMinimized(pid: pid_t) {
        minimizeOrder.removeAll { $0.pid == pid }
    }

    /// The app's most recently minimized window, or nil when
    /// nothing of that app is on record. `bundleID` arrives
    /// lowercased (the command normalizes it).
    ///
    /// Advisory: the caller must verify the id is still one of
    /// the app's minimized windows and fall back when it is not.
    /// A fresh KiwiDesk launched over already-minimized windows
    /// has no record at all, which is exactly that case.
    func lastMinimized(bundleID: String) -> WindowID? {
        minimizeOrder.last { $0.bundleID == bundleID }?.id
    }
}
