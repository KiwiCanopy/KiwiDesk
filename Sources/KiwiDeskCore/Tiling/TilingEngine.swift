import AppKit
import ApplicationServices
import CoreGraphics

/// Applies calculated layouts to real windows.
///
/// Consumes the current state, runs the layout engine for the
/// active space, and animates windows to their target frames.
/// Everything runs in AX coordinates.
@MainActor
public final class TilingEngine {
    public let animation = AnimationEngine()

    /// Pass-scoped (#1055): true only inside `withForcedPass`,
    /// read by `layoutInput` into
    /// `LayoutContext.probesBeyondBounds`. Written nowhere else
    /// — the probe's whole contract is that only an explicit
    /// apply pays it (`TrackCapPlumbingNeedleTests`).
    var probeBeyondBoundsPass = false

    /// The live tiling settings. The animation engine caches
    /// the two duration knobs for its hot path, so mirror them
    /// onto it here: this `didSet` fires on a whole-settings
    /// assignment (profile apply, GUI live-apply) AND on nested
    /// writes like `settings.animations.durationMS = ms` (value
    /// type), so no mutation site can forget the sync — the
    /// invariant lives with the two copies it relates (#51).
    public var settings = TilingSettings() {
        didSet {
            animation.durationMS =
                settings.animations.durationMS
            animation.scrollDurationMS =
                settings.animations.scrollDurationMS
        }
    }

    /// Applies frames off the main thread with frame-dropping
    /// and per-app EnhancedUserInterface toggling. Internal,
    /// not private: its echo-pending seams surface from the
    /// sibling extensions (`recentInstantTarget`, #881).
    let applier = FrameApplier()

    /// A window in an active drag gesture, exempt from ALL frame
    /// application in `retile` — both the main layout loop and
    /// `stashInactive` (#372). The pointer owns a dragged window's
    /// frame, so a retile triggered mid-drag (notably a Space Bar
    /// spring, which reframes the target space's other windows)
    /// must not yank it to its computed slot or stash it into the
    /// corner. The drag handlers set this for the gesture's life
    /// and clear it at drop, when the window's real placement runs
    /// un-exempt: pinned for the duration of the gesture.
    public var dragExemptWindow: WindowID?

    /// App-enforced size bounds, learned from the engine's own
    /// asks (#677) — see `SizeBoundLearner` for the confirm
    /// ladder and `TilingEngine+SizeBounds` for how `retile`
    /// consults it. Engine-owned, transient, per-window tiling
    /// state, like `stashedFrames` below.
    var boundLearner = SizeBoundLearner()
    /// The float fit's own refusal memo (#1091) — beside the
    /// learner because it answers the same question one
    /// subsystem over, and deliberately not an entry IN it:
    /// only the layout loop may record asks there, and a float
    /// never enters the layout. `FloatFitLedger` argues it.
    var floatFitLedger = FloatFitLedger()
    /// The unsolicited-resize correction's memo (#1358), the
    /// third refusal ledger of this shape; the type argues it.
    var unsolicitedCorrections = UnsolicitedResizeMemo()
    /// Where each window was last placed (#1161) — the type doc
    /// carries the argument; stamped in `applyFrame`/`setFrame`.
    var placements = PlacementLedger()

    /// Test seam for the observe gate above: whether one of our
    /// own frame-sets for this window is recent enough that its
    /// echo may still be in flight. Production reads the
    /// applier's stamp (`didRecentlySetFrame`); a fixture that
    /// replaces `animation.apply` writes no stamp and injects the
    /// lag directly, pinning either verdict.
    var echoGraceOverride: (@MainActor (WindowID) -> Bool)?

    /// Raised when a retile-channel observation confirms a
    /// bound (#677): the loop cannot retile itself, so the
    /// `KiwiCore.retile` wrapper consumes this
    /// (`takePendingBoundPlacement`) and runs the placement
    /// pass right after.
    var pendingBoundPlacement = false

    /// Corroboration probes this pass issued (#1439), drained by
    /// `KiwiCore.retile` for the log — `pendingBoundPlacement`'s
    /// shape, since the loop cannot narrate.
    var issuedCorroborationProbes: [(WindowID, CGSize)] = []

    /// The tiled member monocle's `park` keeps showing while a
    /// float holds the focus (#881) — engine-owned transient
    /// state, argued in `TilingEngine+MonocleShown`.
    var monocleShownMembers: [SpaceID: WindowID] = [:]

    /// Original frames of floating windows parked off-screen by
    /// `stashInactive`, keyed by window. Engine-owned, transient,
    /// per-window tiling state — the `dragExemptWindow` precedent —
    /// NOT a `ManagedWindow` property: a parked frame is a
    /// hide-mechanism artifact, not window identity (#412).
    /// Captured on the first stash only, consumed by
    /// `restoreStashed` when the window's space activates again.
    /// Tiled windows need no entry: their frames are recomputed
    /// by the layout on every retile.
    var stashedFrames: [WindowID: CGRect] = [:]

    /// Resolves the AX element of a window (wired to the
    /// event loop's registry).
    public var elementProvider: @MainActor (WindowID) -> AXUIElement? = { _ in
        nil
    }

    /// Tee off every animated frame (AX coords), fired per tick
    /// from `AnimationEngine.apply`. Wired to the focus border
    /// overlays so a ring stays glued to its window mid-slide:
    /// mid-animation this commanded frame is the leading truth —
    /// the WindowServer stream and AX echo both trail it on
    /// slow-AX apps (#594) — so it drives the ring even under
    /// healthy WS tracking. A no-op by default. The instant
    /// `setFrame` path does not tee; its AX or WindowServer
    /// geometry event updates the ring.
    public var onFrameApplied: @MainActor (WindowID, CGRect) -> Void =
        { _, _ in }

    /// Where display *size* enters layout: the AX-coordinate
    /// visible frame of one screen. Every slot the layout
    /// calculates, every track capacity and every resize span
    /// reads its bounds through this hook, so a fixture can
    /// state the display it means instead of inheriting whatever
    /// the host happens to have (#531). Internal, not public:
    /// production never writes it — only tests do, through
    /// `@testable`.
    ///
    /// **It pins size, not topology.** The screen-list facts —
    /// which screens exist and where — enter through the
    /// `allScreenBounds` hook below (#878), and screen
    /// *resolution* (which `NSScreen` a space lands on) still
    /// comes from the three static `screen(…)` resolvers, so a
    /// fixture can shrink the display it lays out against and
    /// fabricate an arrangement, but cannot redirect which
    /// screen object is picked. Subsuming all three under one
    /// display-resolver value is a larger change, and
    /// pre-release nothing blocks it later (§5).
    ///
    /// **What stays outside it lives in one executable place** —
    /// `VisibleBoundsRoutingTests.allowed`, which names every
    /// exempt file and its reason and fails on a new direct call.
    /// Prose copies of that list drifted apart on their first
    /// outing, so this comment does not keep one. The shape of
    /// the exemptions: `static` sites with no instance in hand,
    /// and sites that resolve *several* screens (parking picks
    /// each window's own screen, re-anchor compares two) where
    /// one rect would collapse the distinction.
    ///
    /// So a fixture that pins bounds and calls `calculatedFrames`,
    /// `trackCapacity` or a resize is fully pinned; one that
    /// drives a whole `retile` is not — the per-window screen
    /// pick and bar geometry still run against the real display
    /// (the parking corner's CHOICE follows `allScreenBounds`).
    var visibleBounds: @MainActor (NSScreen) -> CGRect = {
        GeometryUtils.axVisibleFrame(of: $0)
    }

    /// The AX visible frames of every connected screen, for the
    /// per-retile neighbor scan (#878). Separate from
    /// `visibleBounds` because that hook pins the SIZE of one
    /// screen while this one pins TOPOLOGY — which screens
    /// exist and where. The `makeTestCore` factories pin it to
    /// `[]` (no neighbors: the single-screen verdict) so engine
    /// fixtures don't inherit the host's arrangement — the
    /// #523 leak, one hook over — and adjacency suites inject a
    /// fabricated list instead. Production never writes it.
    var allScreenBounds: @MainActor () -> [CGRect] = {
        NSScreen.screens.map {
            GeometryUtils.axVisibleFrame(of: $0)
        }
    }

    public init() {
        applier.elementProvider = { [weak self] id in
            self?.elementProvider(id)
        }
        animation.apply = { [weak self, applier] id, frame, setSize in
            applier.apply(id, frame, setSize: setSize)
            self?.onFrameApplied(id, frame)
        }
        animation.onAnimationStart = { [applier] id in
            applier.beginAnimating(id)
        }
        animation.onAnimationEnd = { [applier] id in
            applier.endAnimating(id)
        }
    }

    /// Recomputes and applies the active space's layout.
    /// `animated: false` snaps windows to their targets in
    /// one frame-set each (Space switches).
    ///
    /// `force` skips the "already there" tolerance check and
    /// (re)issues every frame, and probes past corroborated
    /// bounds once (#1055) — an explicit apply. `reissue` is the
    /// re-issue alone: a Space switch needs it (the check reads
    /// state frames, whose AX echoes lag during rapid switching
    /// and strand windows mid-transition) but not the probe,
    /// under which the learned-bound consumers stand down (#1488).
    ///
    /// `stashAnimated` makes the park of newly-inactive
    /// windows a visible slide to the corner instead of an
    /// instant set — the coordinated space switch (#207), where
    /// the outgoing windows slide out WHILE the incoming ones
    /// slide in. Every other retile keeps the instant default.
    ///
    /// `sizing` is the caller's promise about how every window in
    /// this pass gets its size (#593); promising them all
    /// spring-sized lets a shrinking pane slide its shared edge
    /// instead of snapping. It rides the layout loop only: the
    /// stash park and the float restore below place windows that
    /// sit *outside* the layout, and a promise about the layout
    /// cannot extend to them.
    public func retile(
        state: StateCoordinator,
        animated: Bool = true,
        force: Bool = false,
        reissue: Bool = false,
        newlyCreatedWindow: WindowID? = nil,
        stashAnimated: Bool = false,
        sizing: BatchSizing = .mayInstantSize
    ) {
        guard
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else { return }
        let reissues = force || reissue
        // A forced pass probes past corroborated bounds once
        // (#1055); `withForcedPass` is the one door.
        withForcedPass(force) {
            // The issued set, not the slots (#934).
            let frames = placedFrames(state: state)
            // The #45 invariant, enforced rather than trusted: a
            // newcomer IS an instant size, so no promise survives one.
            // Both arguments meet in this one signature, which makes
            // this the only place the combination is expressible — and
            // the routing guard cannot see it, because it counts
            // occurrences, not combinations.
            let promised: BatchSizing =
                newlyCreatedWindow == nil ? sizing : .mayInstantSize

            for (id, target) in frames {
                // A window in an active drag keeps its user-driven
                // frame: the pointer owns it. Reframing it here would
                // yank it to its computed slot mid-drag — a Space Bar
                // spring retiles the target's OTHER windows but must
                // leave the dragged one under the cursor (#372). Its
                // real placement happens at drop, once the exemption
                // clears.
                if id == dragExemptWindow { continue }
                guard let current = state.windows[id]?.frame
                else { continue }
                // #677: the settled, echo-quiet state frame is the
                // app's answer to the engine's last ask — the gate
                // and its argument live on `observeAppAnswer`. Its
                // verdict doubles as the baseline trust for the ask
                // recorded below.
                let settledNow = observeAppAnswer(
                    for: id,
                    current: current
                )
                // #1439: a due corroboration probe stands in for
                // an ask the anchor already answers and is meant
                // to be issued, so neither skip below applies. A
                // forced pass keeps its own ask (#1055).
                let probe =
                    force
                    ? nil
                    : takeCorroborationProbe(
                        id,
                        current: current,
                        target: target
                    )
                // Tolerance: apps clamp what we set (character
                // grids, minimum sizes), so the reported frame is
                // often a hair off the target. Re-applying an
                // unchanged target just wobbles the window.
                if probe == nil, !reissues,
                    Self.close(current, to: target)
                {
                    animation.cancel(window: id)
                    continue
                }
                // #677: a target the app has twice refused is
                // "already there" too — re-issuing it restarts an
                // animation the window can never perform, forever.
                if probe == nil, !reissues,
                    sizeBoundExplains(
                        id,
                        current: current,
                        target: target
                    )
                {
                    animation.cancel(window: id)
                    continue
                }
                let issued = probe?.frame ?? target
                applyFrame(
                    id,
                    from: current,
                    to: issued,
                    animated: animated,
                    isNewWindow: id == newlyCreatedWindow,
                    sizing: promised
                )
                boundLearner.recordAsk(
                    id,
                    size: issued.size,
                    settledFrom: settledNow
                        ? current.size : probe?.baseline
                )
            }
            stashInactive(
                state: state,
                fallback: screen,
                force: reissues,
                animated: stashAnimated
            )
            restoreStashed(state: state, frames: frames)
        }
    }

    /// Whether we set this window's frame moments ago. Move
    /// events arriving within the grace period are AX echoes
    /// of our own frame-sets, not user drags.
    public func didRecentlySetFrame(_ id: WindowID) -> Bool {
        applier.didRecentlySetFrame(id)
    }

    /// Sets a frame directly (no animation) through the frame
    /// pipeline, so it is echo-tracked like animated frames.
    /// Uses the EUI-bracketed instant path so an un-animated
    /// placement (space switch / stash with animation off) snaps
    /// cleanly instead of triggering the app's own move
    /// animation (which stutters on slow-AX apps).
    public func setFrame(_ id: WindowID, _ frame: CGRect) {
        placements.stamp(id, target: frame)
        applier.applyInstant(id, frame)
    }
}
