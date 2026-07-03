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
    private static let epsilon = 0.1

    public init(from: CGRect, to: CGRect, spring: Spring) {
        self.current = Self.vector(from)
        self.velocity = [0, 0, 0, 0]
        self.target = Self.vector(to)
        self.spring = spring
    }

    /// Redirects the animation to a new target mid-flight.
    public mutating func retarget(to frame: CGRect) {
        target = Self.vector(frame)
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

    private static func vector(_ rect: CGRect) -> [Double] {
        [
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
        ]
    }
}
