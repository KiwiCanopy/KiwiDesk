import Foundation

/// Minimized window tracking and restore ordering in `StateCoordinator`
/// (#40, #673).
extension StateCoordinator {
    /// Record for a minimized window (`WindowManager.rekey`, #308).
    struct MinimizedWindow: Sendable {
        var id: WindowID
        let pid: pid_t
        let bundleID: String?
    }

    /// Records window minimization, newest last. Call while the
    /// window snapshot is still live — the destroy fold erases it
    /// a few lines later. The `removeAll` is not redundant with
    /// the create fold's prune: `WindowManager.rekey` also makes
    /// an id non-nil without passing through that fold
    /// (`EventLoop+AppObservation`).
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

    /// Removes window from minimize tracking, returning true if found (#40).
    @discardableResult
    mutating func forgetMinimized(_ id: WindowID) -> Bool {
        let before = minimizeOrder.count
        minimizeOrder.removeAll { $0.id == id }
        return minimizeOrder.count != before
    }

    /// Clears all minimize records for a terminated process.
    mutating func forgetMinimized(pid: pid_t) {
        minimizeOrder.removeAll { $0.pid == pid }
    }

    /// Returns most recently minimized window ID for bundle ID.
    /// Advisory: the caller must verify the id is still among the
    /// app's minimized windows and fall back when it is not.
    func lastMinimized(bundleID: String) -> WindowID? {
        minimizeOrder.last { $0.bundleID == bundleID }?.id
    }
}
