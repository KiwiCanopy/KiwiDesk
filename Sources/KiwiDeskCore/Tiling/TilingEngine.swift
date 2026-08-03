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
                settings.animations.scrollSpeedMS
        }
    }

    /// Applies frames off the main thread with frame-dropping
    /// and per-app EnhancedUserInterface toggling.
    private let applier = FrameApplier()

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
    /// **It pins size, not topology.** Which screen a space
    /// lands on still comes from `NSScreen` via the three static
    /// `screen(…)` resolvers, so a fixture can shrink the
    /// display it lays out against but cannot fabricate a second
    /// one. Injecting topology would want a display-resolver
    /// value subsuming this hook and those statics — a larger
    /// change, and pre-release nothing blocks it later (§5).
    ///
    /// **What stays outside it lives in one executable place** —
    /// `VisibleBoundsRoutingTests.allowed`, which names every
    /// exempt file and its reason and fails on a new direct call.
    /// Prose copies of that list drifted apart on their first
    /// outing, so this comment does not keep one. The shape of
    /// the exemptions: `static` sites with no instance in hand,
    /// and sites that resolve *several* screens (parking picks a
    /// corner across all of them, re-anchor compares two) where
    /// one rect would collapse the distinction.
    ///
    /// So a fixture that pins bounds and calls `calculatedFrames`,
    /// `trackCapacity` or a resize is fully pinned; one that
    /// drives a whole `retile` is not — parking and bar geometry
    /// still run against the real display.
    var visibleBounds: @MainActor (NSScreen) -> CGRect = {
        GeometryUtils.axVisibleFrame(of: $0)
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

    /// Events that change window structure and require a
    /// retile. Move/resize events are deliberately excluded:
    /// applying frames emits them, which would loop. Focus
    /// changes are handled separately — only focus-driven
    /// layouts (Scrolling, Monocle) re-layout on focus.
    public nonisolated static func shouldRetile(
        after event: KiwiEvent
    ) -> Bool {
        switch event {
        case .windowCreated, .windowDestroyed, .appTerminated,
            .displaysChanged, .windowFloatChanged,
            .windowRekeyed, .windowFullscreenChanged:
            // A re-key swaps the tracked id in one slot; the newly
            // active tab must be placed into that slot's frame
            // (#308), so retile even though the array shape is
            // unchanged.
            // A fullscreen flip changes layout membership like a
            // float flip (#670): entering exempts the slot (the
            // window keeps it, but macOS moved it to its own
            // Space), leaving must re-place it.
            return true
        case .appLaunched, .windowFocused, .windowMoved,
            .windowResized, .windowTitleChanged,
            .nativeSpaceChanged:
            return false
        }
    }

    /// Recomputes and applies the active space's layout.
    /// `animated: false` snaps windows to their targets in
    /// one frame-set each (virtual space switches).
    ///
    /// `force` skips the "already there" tolerance check and
    /// (re)issues every frame. Space switches need it: the
    /// check reads state frames, which are updated by the AX
    /// echoes of our own frame-sets — during rapid
    /// back-and-forth switching those echoes lag, and skipping
    /// based on them leaves windows stranded mid-transition.
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
        newlyCreatedWindow: WindowID? = nil,
        stashAnimated: Bool = false,
        sizing: BatchSizing = .mayInstantSize
    ) {
        guard
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else { return }
        let frames = calculatedFrames(state: state)
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
            // Tolerance: apps clamp what we set (character
            // grids, minimum sizes), so the reported frame is
            // often a hair off the target. Re-applying an
            // unchanged target just wobbles the window.
            if !force, Self.close(current, to: target) {
                animation.cancel(window: id)
                continue
            }
            applyFrame(
                id,
                from: current,
                to: target,
                animated: animated,
                isNewWindow: id == newlyCreatedWindow,
                sizing: promised
            )
        }
        stashInactive(
            state: state,
            fallback: screen,
            force: force,
            animated: stashAnimated
        )
        restoreStashed(state: state, frames: frames)
    }

    /// Applies one frame through the shared animate-or-instant
    /// policy: animated when asked (and a screen exists),
    /// otherwise an instant, echo-tracked set with any
    /// in-flight animation cancelled. The single authority for
    /// this policy — `retile` and the floating keyboard resize
    /// both route here; never copy the branch (a copy already
    /// drifted once, dropping the cancel). The animation screen
    /// is the display the target frame lands on (multi-monitor:
    /// one `DisplayLink` per monitor), falling back to main.
    ///
    /// `sizing` says why this frame is being applied (#593);
    /// it reaches `SizeStep` through the animation and decides
    /// whether a shrinking axis may slide instead of snapping.
    /// `.mayInstantSize` is the default because mismarking is asymmetric —
    /// see `BatchSizing`.
    public func applyFrame(
        _ id: WindowID,
        from current: CGRect,
        to target: CGRect,
        animated: Bool,
        isNewWindow: Bool = false,
        sizing: BatchSizing = .mayInstantSize
    ) {
        if animated,
            let screen = Self.screen(containing: target)
                ?? NSScreen.main
                ?? NSScreen.screens.first
        {
            animation.animate(
                window: id,
                on: screen,
                from: current,
                to: target,
                isNewWindow: isNewWindow,
                sizing: sizing
            )
        } else {
            animation.cancel(window: id)
            setFrame(id, target)
        }
    }

    /// Frames within this distance per edge count as "already
    /// there". Covers rounding and small app-side clamping.
    static let retileTolerance: CGFloat = 2

    static func close(
        _ a: CGRect,
        to b: CGRect
    ) -> Bool {
        abs(a.minX - b.minX) <= retileTolerance
            && abs(a.minY - b.minY) <= retileTolerance
            && abs(a.width - b.width) <= retileTolerance
            && abs(a.height - b.height) <= retileTolerance
    }

    /// Forwards display topology changes to the animator.
    public func displaysChanged() {
        animation.displaysChanged()
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
        applier.applyInstant(id, frame)
    }
}
