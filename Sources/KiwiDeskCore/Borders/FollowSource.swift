/// Who reported a followed frame — shared by the ring's and the
/// sticky mark's `follow`. The follow guards differ by source
/// (#594): mid-animation the commanded per-tick frame leads
/// every echo on slow-AX apps, so it drives the ring and mark;
/// the echo paths stand down.
public enum FollowSource {
    /// A per-tick commanded frame from `AnimationEngine.apply`.
    case animationTick
    /// An AX `.windowMoved` / `.windowResized` echo.
    case axEcho
    /// The steady-state `sync` pass (`updateBorders()` /
    /// `updateStickyMarks()`), whose frame is
    /// `state.windows[id]?.frame` — echo-fed, so mid-animation it
    /// is the frame the motion has already left behind (#596).
    case steadySync

    /// The one follow decision both managers share: does a
    /// reported frame apply, given what currently owns the
    /// window's frame? The tick is the leading truth mid-flight
    /// and always applies; an echo stands down while the
    /// WindowServer stream tracks the window (#285 — a coalesced
    /// late echo would rewind the overlay behind the live
    /// bounds) and while our own animation drives it (#594 —
    /// the echo trails the commanded frame on slow-AX apps).
    /// Hoisted here so the ring and the mark cannot drift: a
    /// new decision INPUT changes this signature, and the
    /// compiler then drags both managers through the change
    /// (that is the mechanism — a guard bolted on beside the
    /// call in one `follow` body is still possible, so review
    /// for it). Each manager passes its own predicates
    /// (`usesWindowServerTracking` vs the broader
    /// `markUsesWindowServerTracking`); only the decision is
    /// shared.
    ///
    /// `steadySync` stands down mid-animation for the same
    /// reason the echo does, one step further out: its frame is
    /// the same echo-fed state, so any `sync` landing mid-flight
    /// (a focus change, a retile burst) snaps the overlay back to
    /// where the window was before the motion started, until the
    /// next tick (≤16 ms) drags it forward again. Observed on
    /// device as a ~31 pt backward snap (#596). Unlike the echo
    /// it ignores `wsTracked`: WindowServer tracking says who
    /// owns the frame in steady state, and this is only about the
    /// window that our own animation is currently moving.
    public func applies(
        wsTracked: Bool,
        animating: Bool
    ) -> Bool {
        switch self {
        case .animationTick:
            return true
        case .axEcho:
            return !wsTracked && !animating
        case .steadySync:
            return !animating
        }
    }
}
