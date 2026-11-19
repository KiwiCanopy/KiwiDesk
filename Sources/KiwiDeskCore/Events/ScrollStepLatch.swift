import CoreGraphics

/// The point travel a trackpad gesture owes before it steps (#1519,
/// and #1656 on a Monocle Space), and which axis and way it names
/// once past it. `ScrollStepMeter` holds the gesture; this is its
/// first step wherever the steps count points (#3482) and a split's
/// naming (#1873). Pure.
public enum ScrollStepLatch {
    /// Travel a trackpad gesture owes before it steps, in points.
    /// A deliberate flick clears it in its first frames; a resting
    /// hand's drift does not.
    static let trackpadThreshold = 24.0

    /// The axis and sign `travel` names once its larger axis passes
    /// the threshold; nil before. Both axes count, and the axis with
    /// the larger travel picks the sign (#1519 ruling).
    static func named(_ travel: CGVector) -> (horizontal: Bool, sign: Int)? {
        let horizontal = abs(travel.dx) > abs(travel.dy)
        let along = horizontal ? travel.dx : travel.dy
        guard abs(along) >= trackpadThreshold else { return nil }
        return (horizontal, along > 0 ? 1 : -1)
    }
}
