import Foundation

extension Space {
    /// Swaps one window id for another in the same layout slot,
    /// preserving array position, focus, and every per-window
    /// marker. Used when a native tab group's active tab changes
    /// (#308): the tracked id is the on-screen tab's `CGWindowID`,
    /// which changes on switch, but the tile, focus, and weights
    /// belong to the group, not the tab. No-op if `old` is absent.
    /// Every id-keyed field here (`windows`, `focused`,
    /// `stackWeights`, `trackBreaks`, `trackWeights`) is guarded by
    /// the `WindowRekeyParityTests` reflection net — except
    /// `scrollRest.slot.window` (#966), which is a bare id inside a
    /// struct rather than an id-keyed container, so only that
    /// suite's `String(describing:)` scan sees it and its count pin
    /// cannot. It migrates for the same reason the rest do: the
    /// slot is the same slot, at the same position in the row, and
    /// a rest still naming the retired id reads as "the focus
    /// moved" — the scrolling viewport would silently stop
    /// re-anchoring for the tab group that just switched.
    public mutating func rekey(_ old: WindowID, to new: WindowID) {
        guard let index = windows.firstIndex(of: old) else {
            return
        }
        windows[index] = new
        if focused == old {
            focused = new
        }
        if let weight = stackWeights.removeValue(forKey: old) {
            stackWeights[new] = weight
        }
        if trackBreaks.remove(old) != nil {
            trackBreaks.insert(new)
        }
        if let weight = trackWeights.removeValue(forKey: old) {
            trackWeights[new] = weight
        }
        if scrollRest?.slot?.window == old {
            scrollRest?.slot?.window = new
        }
    }
}
