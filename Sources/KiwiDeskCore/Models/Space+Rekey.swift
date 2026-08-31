import Foundation

extension Space {
    /// Swaps one window ID for another in place, preserving array
    /// position, focus and per-window markers (#308); no-op if
    /// `old` is absent. Id-keyed fields are guarded by
    /// `WindowRekeyParityTests` — except `scrollRest.slot.window`
    /// (#966), a bare id only that suite's text scan sees; it
    /// migrates so the viewport keeps re-anchoring.
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
