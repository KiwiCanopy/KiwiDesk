import Foundation

/// Swap-boundary detection: whether a swap crosses the stack
/// layout's master/stack partition, so `KiwiCore+ZOrder` knows a
/// cascade re-order is owed. Split out of `KiwiCore+ZOrder` for
/// file size — it is about the swap's array positions, not the
/// z-order restore the rest of that file performs.
extension KiwiCore {
    /// Whether swapping these two windows moves one across
    /// the stack layout's master/stack boundary.
    func crossesStackBoundary(
        _ a: WindowID,
        _ b: WindowID,
        in space: Space
    ) -> Bool {
        guard space.mode == .stack else { return false }
        // Per-space master boundary (#17), matching layout math.
        let boundary = max(
            1,
            tiler.settings.resolvedStack(for: space.id).masterCount
        )
        // Indexes into the tiled list, like the layout's
        // partition and `restoreStackZOrder`: raw
        // `space.windows` would shift the boundary past a
        // floating member. A traveler (#414 v2) resolves too —
        // moot while its swap no-ops, but the two boundary
        // derivations in this file must not contradict.
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        guard let indexA = tiled.firstIndex(of: a),
            let indexB = tiled.firstIndex(of: b)
        else { return false }
        return (indexA < boundary) != (indexB < boundary)
    }
}
