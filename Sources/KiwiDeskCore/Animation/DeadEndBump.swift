import CoreGraphics

/// Pure spring state for dead-end rubber-band animation (#436).
public struct DeadEndBump {
    /// Peak offset toward the wall, in points.
    public static let defaultAmplitude: CGFloat = 8
    public static let minAmplitude: CGFloat = 1
    public static let maxAmplitude: CGFloat = 20

    private var pos: [Double]
    private var vel: [Double]
    private let spring: Spring

    /// Settled when both axes are within this of rest — sub-point
    /// tails are invisible.
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

    /// Re-applies wall impulse preserving velocity, so a held key
    /// reads as one sustained press, not restarted animations
    /// (#436 retarget-in-place).
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
