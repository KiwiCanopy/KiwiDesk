import CoreGraphics

/// The commanded frame a running glide has written but no
/// animation is carrying (#1090) — the in-flight animation
/// target's understudy, for exactly the configurations that
/// have no target to offer.
///
/// `resizeFloating` measures from a FRAME rather than from a
/// stored ratio, weight or length, so every write needs a base
/// that already includes the writes before it. The in-flight
/// animation's target was that base (#129/#1056) and is bounded
/// by the settle; but `AnimationEngine.animate` opens with
/// `guard isEnabled, !reduceMotion()`, so with animations off,
/// under Reduce Motion, or with the engine disabled there is no
/// target at all and the path fell back to the echo-fed frame.
/// At press rate that costs one echo's lag; at a glide's ~100 Hz
/// most frames re-based on the SAME stale echo and 71% of a held
/// resize never happened (measured on device, 2026-08-29).
///
/// **Bounded by the HOLD**, which is the whole of why this is
/// safe where the #881 instant stamp was not (#1056): that
/// record is re-armed by every press that READS it, so an app
/// silently refusing every ask banks commanded growth with no
/// ceiling — the #1057 class. This one is bounded twice over.
/// Only a glide STEP may read it (the per-write scope reaches
/// `AnimationEngine.commandedFrame` as `includingHeldGlide`),
/// so no press can ever measure from another press's record;
/// and `AnimationEngine.clearGlideCommanded` empties it when
/// the run ends. Such an app therefore banks at most one hold's
/// worth, nothing survives the release, and the next press
/// measures from reality again.
///
/// Every floating write records, the arming press included.
/// That press is not a glide step, but its record is exactly
/// the base the glide's FIRST frame needs: the pre-glide wait
/// is the system's key-repeat delay, and an app slow enough to
/// have echoed nothing by then would otherwise cost the hold
/// its own opening step. Recording unconditionally is free
/// because the read is gated — writing more widely than a
/// record is readable cannot bank anything.
///
/// ONE entry rather than a table, which makes that bound
/// structural instead of asserted: `HoldGlide` runs one hold at
/// a time (a new press ends any previous run, latest wins), so a
/// second window's entry could only be a leak. A focus change
/// mid-hold therefore falls back to the echo-fed frame wherever
/// that window has no record of its own, which is the same
/// answer a press from rest gets.
struct GlideCommandedBase {
    private var held: (window: WindowID, frame: CGRect)?

    /// The base for `window`, nil when the running glide is not
    /// writing that window (or no glide is running).
    func frame(for window: WindowID) -> CGRect? {
        held.flatMap { $0.window == window ? $0.frame : nil }
    }

    /// Record what a floating write just commanded. Callers
    /// record unconditionally; it is the READ that carries the
    /// per-WRITE glide scope, and never the hold's lifetime —
    /// a lifetime bit would let an ordinary Lua, CLI or IPC
    /// `resize` measure from the hold's record, and would stay
    /// stuck true for the session if a hold's frame clock died
    /// (display sleep, a disconnect mid-hold).
    mutating func record(_ window: WindowID, frame: CGRect) {
        held = (window, frame)
    }

    /// The run ended, however it ended.
    mutating func clear() {
        held = nil
    }
}
