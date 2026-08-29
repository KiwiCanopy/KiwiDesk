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
extension HoldRepeat {
    /// Steps per second at the glide's first frame. Slow enough
    /// that a short hold past the initial delay reads as fine
    /// adjustment rather than a second jump.
    static let glideStartSteps = 3.5

    /// Steps per second once the ramp is complete.
    static let glideMaxSteps = 18.0

    /// Seconds from the glide's first frame to `glideMaxSteps`.
    static let glideRampSeconds: TimeInterval = 1.5

    /// The ramp: linear in elapsed glide time, clamped at both
    /// ends. Linear on purpose — the value reads back as "how
    /// fast is it moving right now", and an eased curve makes the
    /// same hold duration mean different speeds depending on
    /// where in the ease it lands.
    static func glideSteps(elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return glideStartSteps }
        let progress = min(1.0, elapsed / glideRampSeconds)
        let span = glideMaxSteps - glideStartSteps
        return glideStartSteps + span * progress
    }
}
