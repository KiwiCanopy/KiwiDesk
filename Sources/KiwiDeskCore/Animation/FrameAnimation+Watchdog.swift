import CoreGraphics
import Foundation

/// The settle watchdog's half of `FrameAnimation` (#611).
///
/// An animation that never satisfies `settled` never leaves the
/// engine, so `activeCount` never returns to zero and
/// `onAllAnimationsEnded` stops firing for the rest of the
/// session. #599 removed the one known way to get there; this is
/// the net under it. The full argument, and the two accepted
/// holes, are in `.claude/rules/input-and-animation.md`.
///
/// Split from the main declaration at the §2.1 size target — that
/// file is the animation's own state and stepping, this is the
/// supervisory policy over it. The two stored properties it needs
/// (`age`, `pendingRescueNotice`) have to live with the type.
extension FrameAnimation {
    /// The settle watchdog's bound (#611):
    /// `max(ageFloor, min(ageResponseMultiple × response,
    /// ageCeiling))`.
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
}
