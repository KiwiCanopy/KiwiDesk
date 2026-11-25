import CoreGraphics
import Foundation

/// The whole-zone weight write the Stack zone writer and the
/// fitting-zone writer share (#2967).
extension KiwiCore {
    /// Stores a whole-zone weight step as the render's split judges
    /// it (`RunZone.checkedWeight`, #2967), or cues the limit where
    /// no weight moves `focused` the press's way.
    func storeZoneWeight(
        _ value: Double,
        of focused: WindowID,
        members: [WindowID],
        axis: String,
        delta: Double,
        space: Space,
        in found: (zone: RunZone, context: LayoutContext)?
    ) {
        var checked: Double? = value
        if let found {
            checked = found.zone.checkedWeight(
                value,
                of: focused,
                by: CGFloat(delta),
                in: found.context
            )
        }
        guard let weight = checked else {
            if delta < 0 {
                refuseShrinkAtMinimum(focused, axis: axis)
            } else {
                let at = members.firstIndex(of: focused) ?? 0
                refuseGrowAtNeighborMinimum(
                    focused,
                    anchor: members[StackLayout.nearestMate(of: at)],
                    axis: axis
                )
            }
            return
        }
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[focused] = weight
        }
    }
}
