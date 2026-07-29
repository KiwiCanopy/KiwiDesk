import CoreGraphics
import Foundation

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

    /// What the pass that started this animation promised about
    /// its sizing (#593) — read every tick by `SizeStep` to decide
    /// whether a shrinking axis may follow the spring. Stored per
    /// animation rather than as an engine-wide flag "for the
    /// duration of a retile": `animate` **retargets** a window
    /// already in flight, so an engine flag would let one pass's
    /// promise cover a later pass that never made it.
    /// `retarget(to:sizing:)` makes that an explicit decision
    /// instead, and the newest promise wins — a pass that promises
    /// nothing must restore the snap.
    public private(set) var sizing: BatchSizing

    /// Settled when within this distance at negligible speed.
    /// Sub-pixel tails are invisible but cost real AX calls,
    /// so half a point is close enough (the final frame snaps
    /// to the exact target anyway).
    private static let epsilon = 0.5

    /// Total distance at start (or last retarget); yardstick
    /// for `pastHalfway`.
    private var initialDistance: Double

    /// `sizing` defaults to `.mayInstantSize` — today's first-frame
    /// shrink snap — so a construction site that has no opinion
    /// gets the fail-safe one (#593).
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

    /// Redirects the animation to a new target mid-flight. The
    /// sizing is **required**, not defaulted: an interrupt is
    /// exactly where a stale promise would go unnoticed, and the
    /// newest one wins (#593).
    public mutating func retarget(
        to frame: CGRect,
        sizing: BatchSizing
    ) {
        target = Self.vector(frame)
        self.sizing = sizing
        initialDistance = Self.distance(current, target)
    }

    /// Re-seats the two SIZE springs onto a known on-screen size,
    /// with zero size velocity. Position is untouched.
    ///
    /// The size springs integrate on every animation, but under
    /// `.mayInstantSize` a shrinking axis does not *render* them —
    /// `SizeStep` pins the emitted size to the target from frame
    /// 1 while the spring keeps travelling down from the start
    /// size. So mid-flight the spring and the screen diverge by
    /// up to the whole shrink delta, and the spring is simply not
    /// a claim about the window any more.
    ///
    /// `.allSpringSized` reads that spring *as* the on-screen
    /// size. Switch into it mid-shrink without re-seating and the
    /// window jumps back up by the divergence on the next frame —
    /// and if the interrupted flight was a make-room shrink, the
    /// sibling springing back up re-overlaps the newcomer that
    /// `animate(isNewWindow:)` already painted at full size. That
    /// is #45, reintroduced *across* batches rather than inside
    /// one.
    ///
    /// **Per axis, and only where the two actually disagree** —
    /// the staleness is a property of one axis, not of the
    /// animation. A *growing* axis emits the spring on every due
    /// tick, so it already agrees and must be left alone: zeroing
    /// its velocity would stall a grow that was travelling
    /// correctly (26 pt lost on the first frame after an
    /// interrupt, still 17 pt behind eight frames later — measured
    /// in review). The equality test is what separates them, and
    /// it stays honest under a throttle, where a grow axis does
    /// lag its last emitted size and is reseated too.
    ///
    /// Velocity goes to zero on a reseated axis rather than
    /// carrying over: that axis was not moving on screen — it
    /// snapped once and held — so there is no rate to preserve.
    public mutating func reseatSize(_ size: CGSize) {
        let onScreen = [Double(size.width), Double(size.height)]
        for (offset, value) in onScreen.enumerated() {
            let i = offset + 2
            guard current[i] != value else { continue }
            current[i] = value
            velocity[i] = 0
        }
        // Dead in the one production call site (the `retarget`
        // that follows recomputes it), kept so a public mutating
        // method cannot leave the struct inconsistent on its own.
        initialDistance = Self.distance(current, target)
    }

    /// True once at least half the distance is covered. A
    /// growing window switches to its target size here, where
    /// the ongoing slide masks the single-frame size jump and
    /// the window already sits near its final origin.
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
            // Backstop under the substepping (#599): if a
            // component ever stops being finite it can never come
            // back — `abs(inf - target)` is never within epsilon,
            // so the animation would run forever and take the
            // whole settle signal with it. Force it home instead.
            // A visible jump beats a permanently wedged engine.
            // With the substepping above, a finite input can no
            // longer produce a non-finite output at any `dt`, so
            // the live trigger is a non-finite START — a garbage
            // AX read — not the integrator. Check there first if
            // this ever fires. It is deliberately silent: there
            // is no log seam on a pure value type, and the engine
            // would have to poll for it. A non-finite TARGET is a
            // different matter and is refused upstream, in
            // `AnimationEngine.animate`, because this recovery
            // cannot help there — it would assign the NaN target
            // onto `current` and hand a NaN rect to AX.
            if !current[i].isFinite || !velocity[i].isFinite {
                current[i] = target[i]
                velocity[i] = 0
            }
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
