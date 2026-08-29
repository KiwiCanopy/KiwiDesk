import CoreGraphics

/// The commanded-frame question, answered from whichever record
/// is live (#1090). A caller measuring its next write from what
/// was last COMMANDED — rather than from the echo-fed frame,
/// which lags by whole steps (#129/#1056) — asks one object
/// here, instead of branching on which store happens to hold the
/// answer in this configuration.
///
/// Its own file rather than `AnimationEngine.swift`, which is at
/// §2.1's ceiling; only the stored property lives there, since a
/// Swift extension cannot add one.
extension AnimationEngine {
    /// The frame a commanded resize should measure from, nil
    /// when nothing is pending and the settled frame is the same
    /// truth it always was.
    ///
    /// The in-flight target leads, and the order is load-bearing
    /// rather than incidental: it is the fresher commanded value
    /// whenever both exist, which is the arming press's own
    /// spring still travelling when the first glide frame lands.
    ///
    /// `includingHeldGlide` is the per-WRITE glide scope, and it
    /// is what keeps the second record from becoming the #881
    /// stamp #1056 rejected. Every floating write RECORDS —
    /// including the arming press, whose step would otherwise be
    /// lost whenever its echo has not landed by the time the
    /// glide starts — but only a glide step may READ, so a
    /// record can never carry commanded growth from one press
    /// into the next. Pass the per-write scope and never the
    /// hold's lifetime: `HoldGlide.isApplyingGlideStep` argues
    /// why a lifetime bit answers this wrongly in both
    /// directions.
    public func commandedFrame(
        window: WindowID,
        includingHeldGlide: Bool
    ) -> CGRect? {
        if let target = targetFrame(window: window) {
            return target
        }
        guard includingHeldGlide else { return nil }
        return glideBase.frame(for: window)
    }

    /// Record what a floating write just commanded, so a glide
    /// frame can accumulate from it. Unconditional by design —
    /// the arming press is not a glide step and its record is
    /// exactly the one a glide's first frame needs. What bounds
    /// the record is the READ gate above, plus `clearGlideCommanded`.
    func recordGlideCommanded(
        _ window: WindowID,
        frame: CGRect
    ) {
        glideBase.record(window, frame: frame)
    }

    /// The glide ended, however it ended. Wired to
    /// `HoldGlide.onGlideEnd`, which fires exactly once per run —
    /// release, refusal, failing step, teardown or overrun — and
    /// is what bounds the record by the hold.
    func clearGlideCommanded() {
        glideBase.clear()
    }
}
