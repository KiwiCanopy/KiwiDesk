import Foundation

/// Which windows are minimized, in the order they were (#673).
///
/// One container, two consumers with different questions. A
/// deminiaturize asks "was this one of ours?" so it can classify
/// as `restored` (#40); Open or Focus asks "which window of THIS
/// app went down most recently?" so it can bring exactly that one
/// back. The second question needs an order and an owner, and the
/// destroy fold erases the window snapshot carrying the owner a
/// few lines after filing the id — so both are captured here, at
/// the minimize, while they are still readable, and membership
/// falls out of the same array.
extension StateCoordinator {
    /// One minimized window, as much of it as outlives the
    /// snapshot. `id` is a `var` so a native-tab re-key can swap
    /// it in place like every other id-keyed container (#308).
    struct MinimizedWindow: Sendable {
        var id: WindowID
        /// Carried only so `.appTerminated` can prune a quitting
        /// app's records without consulting the (already erased)
        /// window snapshots.
        let pid: pid_t
        /// Lowercased at record time: every consumer matches
        /// against the command's already-lowercased bundle id.
        let bundleID: String?
    }

    /// Files a minimize, newest last. Call while the window
    /// snapshot is still live — the destroy fold erases it a few
    /// lines later.
    ///
    /// The `removeAll` is not redundant with the create fold's
    /// prune: `WindowManager.rekey` also makes an id non-nil
    /// without passing through that fold, so a re-key onto an id
    /// still carrying a dead window's record would otherwise
    /// double it.
    ///
    /// Staleness is accepted, like `rememberedSpaces`': a window
    /// closed while minimized fires no event, so its entry
    /// lingers for the session. Harmless — a restore that cannot
    /// find the remembered id among the app's live minimized
    /// windows falls back to the first one AX lists.
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

    /// Drops a window's minimize record and reports whether there
    /// was one — which IS the "was this a deminiaturize?" test
    /// (#40), so the create fold needs no second container to
    /// consult. Called on every `.windowCreated`, not only on a
    /// restore: a recycled `CGWindowID` must not inherit a dead
    /// window's record.
    @discardableResult
    mutating func forgetMinimized(_ id: WindowID) -> Bool {
        let before = minimizeOrder.count
        minimizeOrder.removeAll { $0.id == id }
        return minimizeOrder.count != before
    }

    /// Drops every record of a quitting app.
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
