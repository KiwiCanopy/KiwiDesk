import CoreGraphics

/// Who reported a followed frame — shared by the ring's and the
/// sticky mark's `follow`. The follow guards differ by source
/// (#594): mid-animation the commanded per-tick frame leads
/// every echo on slow-AX apps, so it drives the ring and mark;
/// the echo paths stand down.
///
/// This type owns every "which frame does an overlay render"
/// decision — `applies` for a *reported* frame, `syncFrame` for
/// the steady-state rebuild — so the ring and the mark cannot
/// answer either question differently.
public enum FollowSource {
    /// A per-tick commanded frame from `AnimationEngine.apply`.
    case animationTick
    /// An AX `.windowMoved` / `.windowResized` echo.
    case axEcho

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
    public func applies(
        wsTracked: Bool,
        animating: Bool
    ) -> Bool {
        switch self {
        case .animationTick:
            return true
        case .axEcho:
            return !wsTracked && !animating
        }
    }

    /// The frame a steady-state `sync` should render an overlay
    /// at (#596). `spec` is the desired frame the rebuild
    /// computed — `state.windows[id]?.frame`, which is written
    /// only by AX move/resize echoes — and `held` is where the
    /// overlay currently sits, `nil` for one being created now.
    ///
    /// While our own animation drives the window the commanded
    /// per-tick frame is the leading truth, and `spec` is the
    /// echo-fed frame the motion has already left behind. So a
    /// `sync` landing mid-flight (a focus change, a retile burst)
    /// snapped the overlay back to where the window sat before
    /// the motion started, until the next tick (≤16 ms) dragged
    /// it forward — ~31 pt on device. The overlay holds instead,
    /// and takes `spec` the moment the motion stops, which is
    /// also the pass that heals a window whose app never moved.
    ///
    /// A WHOLE-CHOICE hoist, not just the predicate, and
    /// deliberately so: a `sync` is not a *reported* frame, so it
    /// cannot ride `applies` (different question, different
    /// return type), and an enum case would have bought nothing —
    /// exhaustiveness fires inside this type, never at a call
    /// site, so wiring one manager and forgetting the other still
    /// compiles. One body called from both is the only shape that
    /// actually holds them together.
    ///
    /// **Takes no `wsTracked`, and that is a real residual.**
    /// With a live WindowServer stream and no animation of ours —
    /// a user drag — `spec` still lags the live WS bounds, so a
    /// `sync` there snaps the overlay back exactly as above. It is
    /// left alone rather than guarded: standing down on
    /// `wsTracked` would mean `sync` never moves overlay geometry
    /// while the private stream is up, leaning the whole steady
    /// state on it and against the public-fallback doctrine. The
    /// drag path already re-reads WS bounds continuously
    /// (`reconcile`), so it self-corrects within an event.
    public static func syncFrame(
        spec: CGRect,
        held: CGRect?,
        animating: Bool
    ) -> CGRect {
        guard animating else { return spec }
        return held ?? spec
    }
}
