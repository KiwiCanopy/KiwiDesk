/// Shared "+N" overflow grammar count arithmetic (`docs/ui-patterns.md`,
/// #789).
/// Surfaces capping a run route through here so "+1" is never drawn.
enum OverflowSplit {
    /// Returns number of items to draw given capacity and marker constraints.
    static func shown(
        of count: Int,
        fitting capacity: Int,
        withMarker markerCapacity: Int
    ) -> Int {
        guard count > capacity else { return max(count, 0) }
        var shown = min(markerCapacity, capacity)
        if count - shown == 1 { shown -= 1 }
        return max(0, shown)
    }
}
