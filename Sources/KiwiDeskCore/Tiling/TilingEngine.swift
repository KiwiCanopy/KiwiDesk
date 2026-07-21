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
    /// overlays as the AX/AppKit fallback so a ring stays glued to
    /// its window mid-slide; healthy WindowServer tracking ignores
    /// this commanded frame and reads the real bounds instead. A
    /// no-op by default. The instant `setFrame` path does not tee;
    /// its AX or WindowServer geometry event updates the ring.
    public var onFrameApplied: @MainActor (WindowID, CGRect) -> Void =
        { _, _ in }

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
            .windowRekeyed:
            // A re-key swaps the tracked id in one slot; the newly
            // active tab must be placed into that slot's frame
            // (#308), so retile even though the array shape is
            // unchanged.
            return true
        case .appLaunched, .windowFocused, .windowMoved,
            .windowResized, .windowTitleChanged,
            .nativeSpaceChanged:
            return false
        }
    }

    /// The active space's layout inputs — the single source
    /// that `calculatedFrames` and the scroll-offset persist
    /// (`KiwiCore.persistScrollOffset`) both consume, so the
    /// screen pick, floating filter, and context can never
    /// drift between the frames we apply and the offset we
    /// store. `nil` without an active space or a screen.
    func layoutInput(
        state: StateCoordinator
    ) -> (space: Space, tiled: [WindowID], context: LayoutContext)? {
        guard
            let spaceID = state.workspaces.activeSpace,
            let space = state.workspaces[spaceID],
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else { return nil }
        // Space-first reservation (#293): the Space Bar strip
        // comes off the visible frame before any layout — or
        // the App Bar — sees its bounds.
        let bounds = settings.layoutBounds(
            from: GeometryUtils.axVisibleFrame(of: screen)
        )
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: state.workspaces.activeSpace
        )
        let context = settings.context(
            bounds: bounds,
            space: space,
            sticky: Set(
                state.windows.all
                    .filter(\.isSticky)
                    .map(\.id)
            ),
            // Scroll to a tiled-sticky traveler when it is the
            // frontmost window (#431): it has a slot in `tiled`
            // but can never be the membership-guarded `focused`
            // slot. `persistScrollOffset` reads this same
            // `layoutInput`, so the pan and the stored offset stay
            // consistent.
            focusedOverride: state.scrollAnchor(
                of: space,
                tiled: tiled
            )
        )
        return (space, tiled, context)
    }

    /// The frames the active space's layout assigns right
    /// now, without applying them. Used by retiling and by
    /// drag-and-drop slot detection.
    public func calculatedFrames(
        state: StateCoordinator
    ) -> [WindowID: CGRect] {
        guard let input = layoutInput(state: state)
        else { return [:] }
        return LayoutEngine.calculate(
            mode: input.space.mode,
            windows: input.tiled,
            context: input.context
        )
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
    public func retile(
        state: StateCoordinator,
        animated: Bool = true,
        force: Bool = false,
        newlyCreatedWindow: WindowID? = nil
    ) {
        guard
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else { return }
        let frames = calculatedFrames(state: state)

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
                isNewWindow: id == newlyCreatedWindow
            )
        }
        stashInactive(
            state: state,
            fallback: screen,
            force: force
        )
        restoreStashed(state: state, frames: frames)
    }

    /// Applies one frame through the shared animate-or-instant
    /// policy: animated when asked (and a screen exists),
    /// otherwise an instant, echo-tracked set with any
    /// in-flight animation cancelled. The single authority for
    /// this policy — `retile` and the floating keyboard resize
    /// both route here; never copy the branch (a copy already
    /// drifted once, dropping the cancel). The screen pick is
    /// the pre-existing single-screen ceiling (plan item 8).
    public func applyFrame(
        _ id: WindowID,
        from current: CGRect,
        to target: CGRect,
        animated: Bool,
        isNewWindow: Bool = false
    ) {
        if animated,
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        {
            animation.animate(
                window: id,
                on: screen,
                from: current,
                to: target,
                isNewWindow: isNewWindow
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
