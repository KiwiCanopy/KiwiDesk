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

    /// The one follow decision both managers share: which frame
    /// does a reported one render, given what currently owns
    /// the window's frame? Nil = stand down. The tick is the
    /// leading truth mid-flight and always renders — but where
    /// a `pin` says the commanded size re-asks a refused ask
    /// (#677), the truthful render is the commanded ORIGIN at
    /// the pinned size: the app performs our position sets and
    /// refuses the pinned axes, so riding the raw tick would
    /// sweep the overlay out to a size the window never reaches
    /// and snap it back after settle. An echo stands down while
    /// the WindowServer stream tracks the window (#285 — a
    /// coalesced late echo would rewind the overlay behind the
    /// live bounds) and while our own animation drives it
    /// (#594 — the echo trails the commanded frame on slow-AX
    /// apps); when it renders, it renders as reported — the
    /// echo IS reality, so the pin never touches it.
    /// Hoisted here so the ring and the mark cannot drift: a
    /// new decision INPUT changes this signature, and the
    /// compiler then drags both managers through the change
    /// (that is the mechanism — a guard bolted on beside the
    /// call in one `follow` body is still possible, so review
    /// for it). Each manager passes its own predicates
    /// (`usesWindowServerTracking` vs the broader
    /// `markUsesWindowServerTracking`); only the decision is
    /// shared.
    public func renderFrame(
        reported: CGRect,
        pin: SizePin?,
        wsTracked: Bool,
        animating: Bool
    ) -> CGRect? {
        switch self {
        case .animationTick:
            guard let pin, !pin.isEmpty else { return reported }
            return CGRect(
                origin: reported.origin,
                size: CGSize(
                    width: pin.width ?? reported.width,
                    height: pin.height ?? reported.height
                )
            )
        case .axEcho:
            guard !wsTracked, !animating else { return nil }
            return reported
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
    ///
    /// `commanded` is the instant path's twin of the tick's
    /// leading truth (#881): the engine's just-issued
    /// `applyInstant` target while its echo is pending, nil
    /// otherwise. `spec` is echo-fed, so a sync landing between
    /// an instant set and its echo drew the overlay a whole
    /// switch behind — monocle park's focus flip, where the
    /// ring sat at the corner the window had already left
    /// (owner QA 2026-08-18). The stamp is cleared by the first
    /// self-echo, so a clamping app's real frame wins the
    /// moment reality reports, and the echo channel itself is
    /// untouched — this leads only while nothing has reported.
    public static func syncFrame(
        spec: CGRect,
        held: CGRect?,
        animating: Bool,
        commanded: CGRect?
    ) -> CGRect {
        guard !animating else { return held ?? spec }
        return commanded ?? spec
    }
}
