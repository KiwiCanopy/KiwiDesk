import CoreGraphics
import QuartzCore

/// The plate strip's motion along its axis (#1956), as one
/// critically damped spring the render server plays: `offset` is
/// the strip's translation, a page `pageLength` points per Space.
/// The overlay keeps this model beside the animation so a press
/// mid-flight reads where the strip IS and how fast it goes —
/// a burst carries the velocity on rather than restarting.
struct SpaceSlideStrip: Equatable {
    /// Where the spring starts, where it rests, and its speed at
    /// `begin` (points per second, along the axis).
    var from: CGFloat = 0
    var to: CGFloat = 0
    var velocity: CGFloat = 0
    /// Render-server time the spring starts; it holds `from`
    /// until then.
    var begin: CFTimeInterval = 0
    /// The spring's response: the plan's, scaled by the pace.
    var response: TimeInterval = SpaceSlidePlan.response

    /// The spring's natural frequency.
    var omega: CGFloat { 2 * .pi / CGFloat(response) }

    /// `CASpringAnimation`'s parameters for the same spring:
    /// mass 1, damping ratio 1 — no overshoot.
    var stiffness: CGFloat { omega * omega }
    var damping: CGFloat { 2 * omega }

    /// The strip's offset and velocity at render time `now`.
    func state(at now: CFTimeInterval) -> (
        offset: CGFloat, velocity: CGFloat
    ) {
        guard now > begin else { return (from, 0) }
        let t = CGFloat(now - begin)
        let w = omega
        let d0 = from - to
        let decay = exp(-w * t)
        let d = (d0 + (velocity + w * d0) * t) * decay
        let v = (velocity - w * (velocity + w * d0) * t) * decay
        return (to + d, v)
    }

    /// The motion a press at `now` starts: from where the strip is,
    /// at the speed it has, toward `target`, beginning at `begin`,
    /// on the spring `response` gives. A strip already moving
    /// begins at once — waiting would stop it dead for the delay.
    func retargeted(
        to target: CGFloat,
        at now: CFTimeInterval,
        begin planned: CFTimeInterval,
        response: TimeInterval = SpaceSlidePlan.response
    ) -> SpaceSlideStrip {
        let current = state(at: now)
        let moving = abs(current.velocity) > 1
        return SpaceSlideStrip(
            from: current.offset,
            to: target,
            velocity: moving ? current.velocity : 0,
            begin: moving ? now : planned,
            response: response
        )
    }

    /// How long after `begin` the strip stays within `share` of its
    /// travel from rest — the landing the held writes wait for,
    /// solved from THIS motion, since one that carries a reversed
    /// velocity takes longer than one from rest. Scanned in 5 ms
    /// steps over the model, capped at 3 s.
    func settleTime(within share: CGFloat = 0.02) -> CFTimeInterval {
        let band = share * max(abs(to - from), 1)
        let step: CFTimeInterval = 0.005
        var outside: CFTimeInterval = -step
        var t: CFTimeInterval = 0
        while t < 3 {
            if abs(state(at: begin + t).offset - to) > band {
                outside = t
            }
            t += step
        }
        return outside + step
    }

    /// `CASpringAnimation.initialVelocity`: the speed toward the
    /// target as a share of the distance per second.
    var normalizedVelocity: CGFloat {
        let distance = to - from
        guard abs(distance) > 0.5 else { return 0 }
        return velocity / distance
    }
}
