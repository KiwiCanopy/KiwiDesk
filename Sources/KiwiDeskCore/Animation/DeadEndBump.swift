import CoreGraphics

/// Pure spring state for the dead-end rubber-band (#436).
///
/// A directional focus/swap that finds no window beyond the wall
/// gets a wordless "nope, nothing there": the focus ring offsets a
/// few points *toward* the wall and springs back with a small
/// overshoot — the scroll-overscroll idiom, not the login-shake.
/// Two independent scalar springs (dx, dy) pull the offset back to
/// zero after an initial impulse. All math is over plain scalars —
/// no AX, no AppKit — so it is unit-testable and the animator layer
/// only feeds the resulting offset to the ring overlay.
public struct DeadEndBump {
    /// Peak offset toward the wall, in points — a nudge, not a move.
    public static let defaultAmplitude: CGFloat = 8
    public static let minAmplitude: CGFloat = 1
    public static let maxAmplitude: CGFloat = 20

    private var pos: [Double]
    private var vel: [Double]
    private let spring: Spring

    /// Settled when both axes are within this of rest at
    /// negligible speed. Sub-point tails are invisible.
    private static let epsilon = 0.3

    public init(
        offset: CGVector,
        spring: Spring = Spring(
            response: 0.15,
            dampingFraction: 0.45
        )
    ) {
        pos = [Double(offset.dx), Double(offset.dy)]
        vel = [0, 0]
        self.spring = spring
    }

    /// Re-applies the impulse toward the wall while keeping the
    /// current velocity, so a key held against the wall reads as one
    /// sustained press rather than a stack of restarted animations
    /// (#436 retarget-in-place). A fresh dead-end on the other axis
    /// simply overwrites that axis and lets the stale one decay.
    public mutating func reimpulse(offset: CGVector) {
        pos = [Double(offset.dx), Double(offset.dy)]
    }

    /// Advances both springs by `dt`; true once settled back at
    /// rest (offset snapped to exactly zero).
    public mutating func step(dt: Double) -> Bool {
        var settled = true
        for i in 0..<2 {
            spring.step(
                position: &pos[i],
                velocity: &vel[i],
                target: 0,
                dt: dt
            )
            if abs(pos[i]) > Self.epsilon
                || abs(vel[i]) > Self.epsilon
            {
                settled = false
            }
        }
        if settled {
            pos = [0, 0]
            vel = [0, 0]
        }
        return settled
    }

    public var offset: CGVector {
        CGVector(dx: pos[0], dy: pos[1])
    }

    /// The impulse vector for a move that hit the wall in
    /// `direction`, pointing *toward* that wall in AX coords
    /// (y grows downward). Amplitude is clamped to a legible range.
    public static func impulse(
        for direction: Direction,
        amplitude: CGFloat = defaultAmplitude
    ) -> CGVector {
        let a = min(maxAmplitude, max(minAmplitude, amplitude))
        switch direction {
        case .left: return CGVector(dx: -a, dy: 0)
        case .right: return CGVector(dx: a, dy: 0)
        case .up: return CGVector(dx: 0, dy: -a)
        case .down: return CGVector(dx: 0, dy: a)
        }
    }
}
