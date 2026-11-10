import Foundation

/// When each window last held an honored focus (#1840): the
/// first press of Open or Focus lands on the app's most recent
/// one, and a directional tie returns to the window the last
/// step left (#2619). It picks a target only — the cycle's ring
/// order stays fixed (design-decisions ▸ Open or Focus lands on
/// the window you used last). Beside it, when each app was last
/// activated (#3135), on the same tick: KiwiHub's app strip
/// orders by it, an order the panel draws before any pick
/// (design-decisions ▸ KiwiHub's app strip).
extension StateCoordinator {
    /// One honored focus and the process that owns the window —
    /// so the app's exit ends a hidden window's stamp too.
    struct FocusStamp: Sendable, Equatable {
        let pid: pid_t
        let tick: UInt64
    }

    /// The window stamps are written by `rememberHonoredFocus`
    /// alone, the app stamps by the activation report; a close
    /// ends a window's, the app's exit both.
    mutating func forgetRecency(of pid: pid_t) {
        focusRecency = focusRecency.filter { $0.value.pid != pid }
        appRecency[pid] = nil
    }

    /// Stamps `id` as the most recently focused window.
    mutating func stampFocusRecency(_ id: WindowID) {
        guard let window = windows[id] else { return }
        focusTick &+= 1
        focusRecency[id] = FocusStamp(pid: window.pid, tick: focusTick)
    }

    /// Stamps `pid` as the most recently activated app; a pid
    /// that names no process is no identity (#1785).
    mutating func stampAppRecency(_ pid: pid_t) {
        guard pid > 0 else { return }
        focusTick &+= 1
        appRecency[pid] = focusTick
    }

    /// Higher is more recent; 0 for a window never stamped.
    func focusRecencyRank(of id: WindowID) -> UInt64 {
        focusRecency[id]?.tick ?? 0
    }

    /// Higher is more recent: the app's own activation or its
    /// windows' latest focus, whichever came last; 0 for neither.
    func appRecencyRank(of pid: pid_t) -> UInt64 {
        let windows =
            focusRecency.values
            .filter { $0.pid == pid }
            .map(\.tick)
            .max() ?? 0
        return max(appRecency[pid] ?? 0, windows)
    }

    /// The window that held focus last apart from `id` — where a
    /// step to `id` came from (#2619); nil with no other stamp.
    func lastStep(before id: WindowID) -> WindowID? {
        focusRecency.filter { $0.key != id }
            .max { $0.value.tick < $1.value.tick }?.key
    }
}
