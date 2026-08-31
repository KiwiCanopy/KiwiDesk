import Foundation

extension Space {
    /// Swaps one window ID for another across all slot/weight state
    /// (`WindowRekeyParityTests`, #308, #966).
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
