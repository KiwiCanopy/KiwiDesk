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

    /// Records window minimization in chronological order
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
    func lastMinimized(bundleID: String) -> WindowID? {
        minimizeOrder.last { $0.bundleID == bundleID }?.id
    }
}
