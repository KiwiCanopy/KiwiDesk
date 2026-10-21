import Foundation

/// The slot hand-over a trade between two Spaces is built from
/// (#2509): each window takes the other's slot, so neither row
/// changes shape.
extension Space {
    /// Puts `incoming` in `resident`'s slot — its index, its
    /// track break and the weights keyed to it — and its Space
    /// focus where `resident` held it. A handed break becomes
    /// the newcomer's own, since a break leaving with its holder
    /// ends the hand-off (#1387). A no-op unless `resident` is a
    /// member and `incoming` is not.
    public mutating func replace(
        _ resident: WindowID,
        with incoming: WindowID
    ) {
        guard let index = windows.firstIndex(of: resident),
            !windows.contains(incoming)
        else { return }
        windows[index] = incoming
        if trackBreaks.remove(resident) != nil {
            trackBreaks.insert(incoming)
        }
        handedBreaks.remove(resident)
        if let weight = trackWeights.removeValue(forKey: resident) {
            trackWeights[incoming] = weight
        }
        if let weight = stackWeights.removeValue(forKey: resident) {
            stackWeights[incoming] = weight
        }
        if focused == resident { focused = incoming }
        releaseScrollSlot()
    }
}
