import CoreGraphics
import Foundation

/// One in-flight window frame animation.
///
/// Four independent springs (x, y, width, height). Retargeting
/// keeps the current position and velocity, so an interrupted
/// animation redirects smoothly instead of jumping.
///
/// It carries two recovery nets, and they share one shape —
/// `forceSettle()`, after which the engine's ordinary settled
/// handling runs. The component-wise one catches a value that
/// stopped being finite; the age bound below catches a spring that
/// stays finite and simply never converges. Split from
/// `Spring.swift` at the §2.1 size target; the integrator is the
/// other half.
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

    /// The settle watchdog's bound (#611):
    /// `max(ageFloor, ageResponseMultiple × response)`, capped.
    ///
    /// **Both terms are needed, but not for the reason it is
    /// tempting to give.** The floor is *not* slack for a slow-AX
    /// app: `age` counts simulated motion (see below), so a
    /// blocked app costs wall-clock and ages an animation by at
    /// most one tick's worth. Measured against the worst travel
    /// across the 50–1000 ms clamp at 30/60/120 Hz, each term
    /// covers the end where the other runs thin —
    /// `slowestHealthySettleIsPinned` keeps these honest:
    ///
    /// | duration | slowest settle | floor | multiple |
    /// |---|---|---|---|
    /// | 50 ms | 0.20 s | 25× | 4.2× |
    /// | 1000 ms | 2.80 s | **1.8×** | 6.0× |
    ///
    /// So the multiple is the term that holds the slow end, and
    /// the floor buys back the fast end's 4.2× — the thinnest
    /// margin either term has, and the one a future change to the
    /// duration clamp, the `× 1.4` mapping or the integrator would
    /// eat first. `AnimationSettleWatchdogTests` pins both terms
    /// and the inverse.
    ///
    /// The ceiling exists because the multiple scales with a
    /// caller-supplied response, and `Spring.init` clamps that
    /// only from below: without it `Spring(response: 1e6)` buys a
    /// 139-day bound, i.e. a spring can opt out of the watchdog
    /// entirely. It sits far above the largest legitimate bound
    /// (16.8 s at 1000 ms) so it never binds on a shipped spring.
    private static let ageResponseMultiple = 12.0
    private static let ageFloor: TimeInterval = 5
    private static let ageCeiling: TimeInterval = 60

    /// Total distance at start (or last retarget); yardstick
    /// for `pastHalfway`.
    private var initialDistance: Double

    /// Simulated seconds spent stepping toward the *current*
    /// target. Simulated rather than wall-clock on purpose:
    /// `Spring.integratedSpan` caps what one `step` may add, so a
    /// stalled `DisplayLink` (display sleep, a wedged main actor)
    /// hands over one huge `dt` and ages this by only as much as
    /// the spring actually moved. Wall-clock would age an
    /// animation that was not running at all.
    private(set) var age: TimeInterval = 0

    /// Raised by the non-finite net, cleared by
    /// `takeNonFiniteNotice()`. A value type has no log seam of its
    /// own and the engine will not poll for one, so the net leaves
    /// a mark that the tick loop collects on its way past (#611).
    private var pendingRescueNotice = false

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
        let next = Self.vector(frame)
        // A genuinely new target is a new journey, so the age
        // bound restarts with it: a live make-room drag retargets
        // its siblings for as long as the user holds the mouse,
        // and a watchdog that fires on healthy motion is worse
        // than none.
        //
        // Only on a *changed* target, though. A retile loop that
        // re-issues the same placement would otherwise reset the
        // clock forever and blind the watchdog to the one wedge it
        // could plausibly meet in production — an echo/retile
        // feedback loop, which is far more reachable than the
        // pathological spring the bound is written against.
        //
        // A storm of genuinely *different* targets still defers
        // the bound indefinitely, and that is an accepted hole
        // (documented in `.claude/rules/input-and-animation.md`):
        // it is indistinguishable from a long drag from here, and
        // the first target a storm stops on ages normally.
        if next != target {
            age = 0
        }
        target = next
        initialDistance = Self.distance(current, target)
    }

    /// True once at least half the distance is covered. A
    /// growing window switches to its target size here, where
    /// the ongoing slide masks the single-frame size jump and
    /// the window already sits near its final origin.
    public var pastHalfway: Bool {
        Self.distance(current, target) * 2 <= initialDistance
    }

    /// Whether this animation has been stepping toward one target
    /// for longer than any healthy motion to it could take, and so
    /// should be force-settled rather than left to run (#611). The
    /// engine, not this type, owns what happens next: the whole
    /// point is that a stuck animation never leaves `animations`,
    /// which is what kills `onAllAnimationsEnded` for the session.
    var isOverdue: Bool {
        let scaled = min(
            Self.ageResponseMultiple * spring.response,
            Self.ageCeiling
        )
        return age > max(Self.ageFloor, scaled)
    }

    /// Advances by `dt`; returns true when settled.
    ///
    /// A caller that wants the non-finite net's diagnostics must
    /// drain `takeNonFiniteNotice()` after each call — the notice
    /// is raised here and reported by whoever is driving.
    public mutating func step(dt: Double) -> Bool {
        // The interval the integrator would accept, so a refused
        // one ages nothing. Deliberately NOT the same predicate
        // `Spring.step` applies: that also refuses when the
        // spring's own `maxStableStep` is unusable, and such a
        // spring integrates to a standstill. Ageing it anyway is
        // what lets the watchdog rescue it — sharing one predicate
        // here would hand that case straight back to the wedge
        // (`aFrozenSpringIsStillRescued` pins it).
        age += Spring.integratedSpan(dt)
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
            // this ever fires; the engine logs it (#611), so
            // "there was no symptom" is no longer the answer. A
            // non-finite TARGET is a different matter and is
            // refused upstream, in `AnimationEngine.animate`,
            // because this recovery cannot help there — it would
            // assign the NaN target onto `current` and hand a NaN
            // rect to AX.
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

    /// Snaps to the exact target and stops dead. The single
    /// recovery shape: a clean settle, the non-finite net and the
    /// age watchdog all end here, and the caller then runs its
    /// ordinary settled handling.
    mutating func forceSettle() {
        current = target
        velocity = [0, 0, 0, 0]
    }

    /// Whether the **non-finite** net fired since this was last
    /// asked, clearing the flag so one rescue reports once even
    /// though the animation keeps running for many more ticks.
    /// Named for that net specifically: the age watchdog is the
    /// driver's own decision and needs no notice from here.
    mutating func takeNonFiniteNotice() -> Bool {
        defer { pendingRescueNotice = false }
        return pendingRescueNotice
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
