import CoreGraphics
import Foundation

/// Damped spring parameters, matching SwiftUI's
/// `.spring(response:dampingFraction:)` semantics.
public struct Spring: Sendable, Equatable {
    public let stiffness: Double
    public let damping: Double

    public init(
        response: Double = 0.35,
        dampingFraction: Double = 0.85
    ) {
        let omega = 2 * .pi / max(response, 0.01)
        self.stiffness = omega * omega
        self.damping = 2 * dampingFraction * omega
    }

    /// Advances one scalar by `dt` seconds (semi-implicit
    /// Euler). Mutates position and velocity in place.
    public func step(
        position: inout Double,
        velocity: inout Double,
        target: Double,
        dt: Double
    ) {
        let acceleration =
            -stiffness * (position - target)
            - damping * velocity
        velocity += acceleration * dt
        position += velocity * dt
    }
}

/// One in-flight window frame animation.
///
/// Four independent springs (x, y, width, height). Retargeting
/// keeps the current position and velocity, so an interrupted
/// animation redirects smoothly instead of jumping.
public struct FrameAnimation: Sendable {
    public private(set) var current: [Double]
    public private(set) var velocity: [Double]
    public private(set) var target: [Double]
    public let spring: Spring

    /// Settled when within this distance at negligible speed.
    /// Sub-pixel tails are invisible but cost real AX calls,
    /// so half a point is close enough (the final frame snaps
    /// to the exact target anyway).
    private static let epsilon = 0.5

    /// Total distance at start (or last retarget); yardstick
    /// for `pastHalfway`.
    private var initialDistance: Double

    public init(from: CGRect, to: CGRect, spring: Spring) {
        self.current = Self.vector(from)
        self.velocity = [0, 0, 0, 0]
        self.target = Self.vector(to)
        self.spring = spring
        self.initialDistance = Self.distance(
            self.current,
            self.target
        )
    }

    /// Redirects the animation to a new target mid-flight.
    public mutating func retarget(to frame: CGRect) {
        target = Self.vector(frame)
        initialDistance = Self.distance(current, target)
    }

    /// True once at least half the distance is covered. Sizes
    /// are applied stepwise (start size until here, target
    /// size after): a resize forces the app to re-lay-out its
    /// content, which is far too expensive per frame.
    public var pastHalfway: Bool {
        Self.distance(current, target) * 2 <= initialDistance
    }

    /// Advances by `dt`; returns true when settled.
    public mutating func step(dt: Double) -> Bool {
        var settled = true
        for i in 0..<4 {
            spring.step(
                position: &current[i],
                velocity: &velocity[i],
                target: target[i],
                dt: dt
            )
            if abs(current[i] - target[i]) > Self.epsilon
                || abs(velocity[i]) > Self.epsilon
            {
                settled = false
            }
        }
        if settled {
            current = target
            velocity = [0, 0, 0, 0]
        }
        return settled
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
