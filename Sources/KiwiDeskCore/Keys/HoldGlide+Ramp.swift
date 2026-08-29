import Foundation

/// The velocity ramp of a held resize (#1082, owner ruling
/// 2026-08-29), replacing #1056's interval acceleration. A hold
/// does not re-fire on a timer — it GLIDES: one step per display
/// frame, each moving `glideSteps(elapsed:) × dt` of the press's
/// own delta.
///
/// **Speed is counted in steps per second, not points.** The
/// press's delta is the user's unit of intent, and an absolute
/// points-per-second glide is discontinuous with it at both ends
/// (owner ruling, 2026-08-29): someone who binds a 10 pt
/// precision step would have it overridden by an
/// eighteen-of-their-steps-per-second glide the moment they
/// hold, and someone on a 200 pt step would find the hold
/// SLOWER than tapping — 180 pt/s is under one of their steps
/// per second. Scaling the press's own delta makes the glide
/// continuous with the tap by construction, at every setting of
/// `resize.step` (which the decoder clamps to 1…10000 points, a
/// four-decade range no absolute speed can serve).
///
/// **Why the tick is a display frame and the amount rides `dt`.**
/// What the eye judges is displacement per RENDERED frame, and
/// the display draws when it draws: ticking faster than the
/// refresh produces no extra frames, only more accumulated
/// movement in each one. So a shorter interval buys speed, never
/// smoothness — they are one dial, which is why #1056's shrinking
/// interval could not fix the chunkiness it was aimed at. Pinning
/// the tick to the frame and scaling by that frame's own `dt`
/// makes the ramp refresh-rate independent: 60 Hz, 120 Hz and a
/// ProMotion panel changing rate mid-hold all travel at the same
/// steps per second, with a faster panel spending its extra
/// frames on finer motion instead of going quicker.
///
/// That fineness has a floor, and it is not this file's: the
/// resize retile is deliberately UN-forced, so a computed frame
/// within the engine's ±2 pt tolerance is not applied. The STORE
/// still advances every frame — the tolerance can only delay a
/// sub-tolerance step, never lose it (`KiwiCore.resize` argues
/// the un-forced choice) — so the travel is unchanged and a
/// panel fast enough to ask for sub-2 pt frames simply lands
/// them every second or third frame instead. Refresh-rate
/// independence is a claim about SPEED, which holds exactly;
/// read the smoothness claim as bounded by that quantum rather
/// than unlimited.
///
/// The constants below are feel, retuned at the machine.
/// `HoldGlideRampTests` pins only the SHAPE (flat start, monotone
/// ramp, clamped ceiling), derived from these values, so a retune
/// reds nothing.
extension HoldGlide {
    /// Steps per second at the glide's first frame. Bounded from
    /// BELOW by two things rather than chosen for feel (designer
    /// round, 2026-08-29):
    ///
    /// - It must clear the fineness floor, which is
    ///   `2 pt ÷ step × refresh`: 2.4 steps/s at 60 Hz and 4.8 at
    ///   120 Hz for the default 50 pt step. Below it the glide
    ///   asks for frames the un-forced retile's ±2 pt tolerance
    ///   does not apply, so a ProMotion panel spends its extra
    ///   refreshes on nothing. The first cut shipped 3.5, under
    ///   the 120 Hz floor.
    ///
    /// Bounded from ABOVE by overshoot: a release reaction of
    /// ~150 ms should cost at most one step — the unit of intent,
    /// and the amount one tap the other way undoes — which is
    /// ≈6.7 steps/s.
    ///
    /// A third consideration was dropped rather than kept as
    /// decoration (docs review, 2026-08-29): "it must beat
    /// mashing the chord by hand" reads like a bound but names
    /// no measured rate, so it constrained nothing and 6.0 is
    /// not derived from it. The two above already bracket the
    /// value to [4.8, 6.7]. If someone measures a sustained
    /// mash rate on a three-modifier chord, it becomes a real
    /// lower bound and belongs back here WITH the number.
    ///
    /// Deliberately NOT justified as "fine adjustment": that is
    /// what a small configured step is for. The tap owns
    /// precision and the glide owns travel, so a start speed
    /// duplicating the tap's job taxes the glide's.
    static let glideStartSteps = 6.0

    /// Steps per second once the ramp is complete. The
    /// "powerful on demand" end, deliberately uncapped-feeling:
    /// it costs ~2.7 steps of overshoot at a 150 ms reaction,
    /// which is only acceptable in a regime where the user has
    /// declared they are travelling — and it is the RAMP that
    /// establishes that, not the ceiling. Lowering this to buy
    /// back overshoot would make the long haul permanently worse
    /// to protect a case the ramp duration already protects.
    static let glideMaxSteps = 18.0

    /// Seconds from the glide's first frame to `glideMaxSteps`.
    ///
    /// Owner-ruled on device at 1.8 s (2026-08-29), OVERRIDING a
    /// derivation that said 2.5 — recorded rather than quietly
    /// replaced, because the derivation is still the reasoning a
    /// future retune should start from.
    ///
    /// The derivation: the ceiling should arrive at about one
    /// screen-span of travel at the default step, which at a mean
    /// 12 steps/s and 30 steps to cross ~1500 pt is 2.5 s. The
    /// first cut shipped 1.5 s, reaching the ceiling at ~800 pt,
    /// so the ordinary adjustment ended at top speed — where
    /// overshoot is worst. Both of those still hold.
    ///
    /// What the device said: 2.5 s read as "a bit slow", and it
    /// is the only constant that got slower between the two
    /// builds tried — the start went 3.5 → 6.0 in the same
    /// change, so a hold that felt slower could only be slower to
    /// ACCELERATE. 1.8 s reaches the ceiling at ~1080 pt, about
    /// two thirds of a span: it keeps most of the plateau the
    /// long ramp bought (the speed still moves only ~2 steps/s
    /// across the first 300 ms, so a short hold stays a
    /// learnable, near-constant rate) while cutting the wait for
    /// top speed by a third.
    ///
    /// Do NOT read the derivation as settled against the device.
    /// Feel outranks it here: the whole constant exists to be
    /// judged by hand, and the same hands caught the two errors
    /// this feature's design turned on.
    static let glideRampSeconds: TimeInterval = 1.8

    /// The ramp: linear in elapsed glide time, clamped at both
    /// ends.
    ///
    /// Linear because **displacement is what the user controls,
    /// and displacement is the integral**. A velocity linear in
    /// time already makes distance quadratic in hold duration; an
    /// ease-IN makes it cubic and unlearnable, and an ease-OUT is
    /// a plateau wearing a curve — reachable by moving the two
    /// endpoints above, which a guard can pin, where a curve is a
    /// fifth free parameter nothing can. (The first cut argued
    /// this as "an eased curve makes the same hold duration mean
    /// different speeds depending on where in the ease it lands",
    /// which is true of a linear ramp too and so defended
    /// nothing — a wrong reason in a docstring is how the next
    /// retune goes wrong.)
    /// The `elapsed > 0` arm is DEFENSIVE, not a protected
    /// invariant (code review, 2026-08-29): `glideElapsed` starts
    /// at zero and only accumulates a `dt` the driver has already
    /// proved positive, and zero returns `glideStartSteps`
    /// through the arithmetic anyway. It is kept because the
    /// function is `static` and reachable from anywhere, not
    /// because a caller can reach it.
    static func glideSteps(elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return glideStartSteps }
        let progress = min(1.0, elapsed / glideRampSeconds)
        let span = glideMaxSteps - glideStartSteps
        return glideStartSteps + span * progress
    }
}
