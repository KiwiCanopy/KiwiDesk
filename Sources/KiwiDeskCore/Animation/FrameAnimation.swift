import CoreGraphics
import Foundation

/// In-flight 4D window frame animation (x, y, width, height springs).
public struct FrameAnimation: Sendable {
    public private(set) var current: [Double]
    public private(set) var velocity: [Double]
    public private(set) var target: [Double]
    public let spring: Spring

    /// Sizing promise for this animation pass (#593).
    public private(set) var sizing: BatchSizing

    /// Epsilon threshold for settling distance and velocity (0.5 pt).
    private static let epsilon = 0.5

    /// Initial distance to target for halfway calculation.
    private var initialDistance: Double

    /// Simulated seconds spent stepping towards current target (#611).
    private(set) var age: TimeInterval = 0

    /// Flag set by non-finite recovery net (#611).
    var pendingRescueNotice = false

    /// Initializes animation with optional sizing promise (#593).
    public init(
        from: CGRect,
        to: CGRect,
        spring: Spring,
        sizing: BatchSizing = .mayInstantSize
    ) {
        self.current = Self.vector(from)
        self.velocity = [0, 0, 0, 0]
        self.target = Self.vector(to)
        self.spring = spring
        self.sizing = sizing
        self.initialDistance = Self.distance(
            self.current,
            self.target
        )
    }

    /// Retargets animation mid-flight with a new sizing promise
    /// (#593). The watchdog clock restarts only on a CHANGED
    /// target (#611): an echo/retile loop re-issuing an identical
    /// rect must not reset the clock forever and blind the
    /// watchdog to the one wedge it can meet in production. Keyed
    /// on the target alone — a pass changing only its sizing
    /// promise has not restarted the journey.
    public mutating func retarget(
        to frame: CGRect,
        sizing: BatchSizing
    ) {
        let next = Self.vector(frame)
        if next != target {
            age = 0
        }
        target = next
        self.sizing = sizing
        initialDistance = Self.distance(current, target)
    }

    /// Re-seats size springs onto the on-screen size, per axis and
    /// only where spring and screen disagree (#45): under
    /// `.mayInstantSize` a shrinking axis renders the target while
    /// the spring travels on, so switching to `.allSpringSized`
    /// without re-seating jumps the window back up by the
    /// divergence — #45 reintroduced ACROSS batches. A growing
    /// axis already agrees and must be left alone (zeroing its
    /// velocity stalls a healthy grow — measured in review).
    public mutating func reseatSize(_ size: CGSize) {
        let onScreen = [Double(size.width), Double(size.height)]
        for (offset, value) in onScreen.enumerated() {
            let i = offset + 2
            guard current[i] != value else { continue }
            current[i] = value
            velocity[i] = 0
        }
        initialDistance = Self.distance(current, target)
    }

    /// True once at least half the distance is covered (#45, #47).
    public var pastHalfway: Bool {
        Self.distance(current, target) * 2 <= initialDistance
    }

    /// Advances simulation by `dt`; returns true when settled (#599, #611).
    public mutating func step(dt: Double) -> Bool {
        age += Spring.integratedSpan(dt)
        var settled = true
        for i in 0..<4 {
            spring.step(
                position: &current[i],
                velocity: &velocity[i],
                target: target[i],
                dt: dt
            )
            // Non-finite recovery net (#599, #611): a component
            // that stops being finite can never settle, so force
            // it home. The live trigger is a non-finite START (a
            // garbage AX read) — check there first if this fires.
            // A non-finite TARGET is refused upstream in `animate`;
            // this recovery would hand the NaN straight to AX.
            if !current[i].isFinite || !velocity[i].isFinite {
                current[i] = target[i]
                velocity[i] = 0
                pendingRescueNotice = true
            }
            if abs(current[i] - target[i]) > Self.epsilon
                || abs(velocity[i]) > Self.epsilon
            {
                settled = false
            }
        }
        if settled {
            forceSettle()
        }
        return settled
    }

    /// Snaps current state directly to target with zero velocity.
    mutating func forceSettle() {
        current = target
        velocity = [0, 0, 0, 0]
    }

    public var frame: CGRect {
        CGRect(
            x: current[0],
            y: current[1],
            width: current[2],
            height: current[3]
        )
    }

    public var targetFrame: CGRect {
        CGRect(
            x: target[0],
            y: target[1],
            width: target[2],
            height: target[3]
        )
    }

    private static func distance(
        _ a: [Double],
        _ b: [Double]
    ) -> Double {
        var sum = 0.0
        for i in 0..<4 {
            sum += (a[i] - b[i]) * (a[i] - b[i])
        }
        return sum.squareRoot()
    }

    private static func vector(_ rect: CGRect) -> [Double] {
        [
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
        ]
    }
}
