import CoreGraphics

/// The commanded frame a floating resize has written but no
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
/// **A commanded base stored here must be bounded, and this one
/// is bounded at both ends of its life.** It is written by every
/// floating write, but READ only by a glide step (the per-write
/// scope reaches `AnimationEngine.commandedFrame` as
/// `includingHeldGlide`), so no press can ever measure from
/// another press's record; and it is CLEARED at the start of
/// every physical press (`HoldGlide.onFireBegan`), so every
/// glide's record chain provably begins with its own arming
/// press. The first bound is what stops commanded growth banking
/// across presses on an app that silently refuses every ask — the
/// #1057 class, and the objection #1056 raised when the #881
/// instant stamp was tried as this base. The second stops a
/// record left by an unrelated earlier press being read by a
/// later hold that reaches the same window.
///
/// **Why a second store rather than the #881 stamp with a read
/// gate on it.** Once the gate exists, banking is no longer what
/// separates them — the lifetime is.
/// `FrameApplier.instantTarget` retires on the window's first
/// self-echo and after a one-second grace, both of which are
/// correct for the thing it serves (an overlay sync, where
/// reality reported beats a commanded guess). A glide emits
/// self-echoes continuously, so that stamp would clear under the
/// glide and hand the next frame the echo again — the defect
/// this type exists to close. Do not merge the two: they answer
/// the same question with deliberately different lifetimes.
///
/// Every floating write records, the arming press included. That
/// press is not a glide step, but its record is exactly the base
/// the glide's FIRST frame needs: the pre-glide wait is the
/// system's key-repeat delay, and an app slow enough to have
/// echoed nothing by then would otherwise cost the hold its own
/// opening step. Recording more widely than the record can be
/// read cannot bank anything, which is what makes that free.
///
/// ONE entry rather than a table, which makes the single-hold
/// bound structural instead of asserted: `HoldGlide` runs one
/// hold at a time (a new press ends any previous run, latest
/// wins), so a second window's entry could only be a leak. A
/// glide that reaches a window this press never wrote — a focus
/// change mid-hold — therefore finds nothing and falls back to
/// the echo-fed frame, which is the same answer a press from
/// rest gets.
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

    /// A new press has begun. Never wired to the glide's END:
    /// that seam fires only for a run that GLIDED and, on the
    /// refusal path, fires from inside the very command that
    /// then records — `KiwiCore+HoldGlide.wireFireBegan` carries
    /// the worked argument.
    mutating func clear() {
        held = nil
    }
}
