import CoreGraphics

/// The commanded-frame question, answered from whichever record
/// is live (#1090). A caller measuring its next write from what
/// was last COMMANDED — rather than from the echo-fed frame,
/// which lags by whole steps (#129/#1056) — asks one object
/// here, instead of branching on which store happens to hold the
/// answer in this configuration.
///
/// **This is not the only record of what was last commanded, and
/// the two have separate domains rather than a precedence:**
/// geometry that ACCUMULATES asks `commandedFrame` below; an
/// overlay SYNC reads the #881 instant stamp
/// (`TilingEngine.recentInstantTarget`), which retires on the
/// window's first self-echo. A consumer reaching for the wrong
/// one gets the right answer most of the time, which is why the
/// split is stated here rather than left to be rediscovered.
///
/// Its own file rather than `AnimationEngine.swift`, which is at
/// §2.1's ceiling; only the stored property lives there, since a
/// Swift extension cannot add one.
extension AnimationEngine {
    /// The frame a commanded resize should measure from, nil
    /// when nothing is pending and the settled frame is the same
    /// truth it always was.
    ///
    /// **The in-flight target leads, by ruling rather than by
    /// derivation.** Where both exist because `resizeFloating`
    /// wrote them together they hold the same value, so that
    /// case decides nothing. The case that decides it is a
    /// target some OTHER subsystem started for this window
    /// mid-hold — a float clamp, a stash restore, a re-anchor.
    /// That target is a commanded frame for the window and the
    /// later one, so it wins. The residue, named rather than
    /// hidden: such an animation retargets the glide's
    /// accumulation onto that other intent, so a hold running
    /// through one travels from where that pass put the window
    /// rather than from where the hold had got to.
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

    /// A new physical press has begun. Wired to
    /// `HoldGlide.onFireBegan`, which fires once per press before
    /// its binding body runs — deliberately NOT to `onGlideEnd`,
    /// which fires only for a run that glided and, on the refusal
    /// path, fires from inside the command that then records.
    /// `KiwiCore+HoldGlide.wireFireBegan` carries that argument.
    func clearGlideCommanded() {
        glideBase.clear()
    }
}
