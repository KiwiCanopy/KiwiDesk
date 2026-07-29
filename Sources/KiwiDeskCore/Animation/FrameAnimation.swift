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
    /// most one tick's worth.
    ///
    /// The real argument is a margin one. Each term is the thin
    /// one at the end the other covers — the multiple at the fast
    /// end, the flat floor at the slow end — so keeping both is
    /// what holds the worst case well clear of the slowest healthy
    /// settle. Neither term *alone* would fire on today's
    /// measurements, so this buys headroom against a future change
    /// to the duration clamp, the `× 1.4` mapping or the
    /// integrator, rather than fixing a live defect.
    ///
    /// The ratios that argument rests on are computed and asserted
    /// by `slowestHealthySettleIsPinned`, not restated here: a
    /// number transcribed into prose drifts (#511), and this one
    /// would have been transcribed into three files.
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
        // re-issues an identical rect would otherwise reset the
        // clock forever and blind the watchdog to the one wedge it
        // could plausibly meet in production — an echo/retile
        // feedback loop, which is far more reachable than the
        // pathological spring the bound is written against. The
        // comparison is exact, so a loop whose rect wobbles by a
        // point (an app-enforced minimum bouncing the placement)
        // still resets; see the accepted hole in the rule file.
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
        // Outside the branch deliberately, though it is journey
        // state too. Rebasing it on an identical target is the
        // pre-existing behaviour of the `.midSlide` grow policy's
        // halfway yardstick (#45/#47), which has no coverage of
        // its own; changing it here would be an unrelated,
        // untested change to the size channel. The shipped
        // `.throttledSmooth` never reads `pastHalfway`, so this
        // is inert today.
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
        // How much simulated time this interval represents — a
        // property of `dt` alone. `Spring.step` separately asks
        // whether the spring can integrate at all, and a spring
        // that cannot (an unusable `maxStableStep`) stands still
        // without ever settling. Age must count elapsed simulated
        // time either way; that is what makes it a watchdog rather
        // than a progress meter, and it is the only reason such a
        // spring is ever rescued (`aFrozenSpringIsStillRescued`).
        age += Spring.integratedSpan(dt)
        var settled = true
        for i in 0..<4 {
            spring.step(
                position: &current[i],
                velocity: &velocity[i],
                target: target[i],
                dt: dt
            )
            // Backstop under the substepping (#599): a component
            // that stops being finite can never come back, since
            // `abs(inf - target)` is never within epsilon — so
            // force it home rather than let it run forever. With
            // the substepping in place a finite input cannot
            // produce a non-finite output, so the live trigger is
            // a non-finite START (a garbage AX read); check there
            // first if this fires, and the engine logs it (#611)
            // so there will be a symptom to check. A non-finite
            // TARGET is refused upstream in `animate` instead —
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
    ///
    /// A flag rather than a richer `step` return because the net
    /// repairs in place — after `step` there is nothing left to
    /// observe, so a caller cannot derive this by inspection, and
    /// a pre-step check would only see a non-finite *entry*
    /// (today's sole live trigger, but not the one a future
    /// integrator change would produce). It stays a flag while
    /// there is exactly **one** production caller draining it on
    /// the next line; a second caller is the trigger to fold it
    /// into `step`'s result instead.
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
