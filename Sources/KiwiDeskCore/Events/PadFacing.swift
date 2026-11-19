import CoreGraphics

/// Which way each pad axis runs against the point deltas, for one
/// touch (#3505): +1 where a finger move and the point delta on that
/// axis share a sign, -1 where they do not — the pad's axes have no
/// Natural scrolling flip, macOS's or KiwiDesk's, and the point
/// deltas have had it. An axis is read once, when its net finger
/// travel since the touch began reaches `floor` mm beside any net
/// point travel, then fixed for the touch: both nets measure one
/// movement, so they agree in sign. Pure.
struct PadFacing: Sendable {
    /// The net finger travel an axis owes before its way is read,
    /// in mm: below it a frame's lag between the two readings could
    /// name the wrong sign.
    static let floor = 1.0

    private var points = CGVector.zero
    private var finger = CGVector.zero
    private var x: Double?
    private var y: Double?

    /// Adds one event's point delta.
    mutating func add(points delta: CGVector) {
        points.dx += delta.dx
        points.dy += delta.dy
        settle()
    }

    /// Adds one finger move in mm, the pad's axes.
    mutating func add(finger move: CGVector) {
        finger.dx += move.dx
        finger.dy += move.dy
        settle()
    }

    /// The axis's way, +1 or -1; nil while it is unread.
    func way(horizontal: Bool) -> Double? { horizontal ? x : y }

    private mutating func settle() {
        if x == nil { x = Self.read(points.dx, finger.dx) }
        if y == nil { y = Self.read(points.dy, finger.dy) }
    }

    private static func read(_ points: Double, _ finger: Double) -> Double? {
        guard points != 0, abs(finger) >= floor else { return nil }
        return (points > 0) == (finger > 0) ? 1 : -1
    }
}
