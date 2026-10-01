import Foundation

/// When each window last held an honored focus (#1840): the
/// first press of Open or Focus lands on the app's most recent
/// one. It picks a target only — the cycle's ring order stays
/// fixed (design-decisions ▸ Open or Focus lands on the window
/// you used last).
extension StateCoordinator {
    /// One honored focus and the process that owns the window —
    /// so the app's exit ends a hidden window's stamp too.
    struct FocusStamp: Sendable, Equatable {
        let pid: pid_t
        let tick: UInt64
    }

    /// Stamps `id` as the most recently focused window.
    mutating func stampFocusRecency(_ id: WindowID) {
        guard let window = windows[id] else { return }
        focusTick &+= 1
        focusRecency[id] = FocusStamp(pid: window.pid, tick: focusTick)
    }

    /// Higher is more recent; 0 for a window never stamped.
    func focusRecencyRank(of id: WindowID) -> UInt64 {
        focusRecency[id]?.tick ?? 0
    }
}
