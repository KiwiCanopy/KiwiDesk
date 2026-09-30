import Foundation

/// When each tracked window last held an honored focus (#1840):
/// the first press of Open or Focus lands on the app's most
/// recent one. It picks a target only — the cycle's ring order
/// stays fixed (design-decisions ▸ Close-return focus).
extension StateCoordinator {
    /// Stamps `id` as the most recently focused window.
    mutating func stampFocusRecency(_ id: WindowID) {
        guard windows[id] != nil else { return }
        focusTick &+= 1
        focusRecency[id] = focusTick
    }

    /// Higher is more recent; 0 for a window never stamped.
    func focusRecencyRank(of id: WindowID) -> UInt64 {
        focusRecency[id] ?? 0
    }
}
