import AppKit
import ApplicationServices
import CoreGraphics

/// Tunable tiling parameters (later fed from init.lua).
public struct TilingSettings: Sendable, Equatable, Codable {
    public var gapsGlobal = Gaps()
    /// `gap_override[space_id]` beats the global gaps.
    public var gapsOverride: [SpaceID: Gaps] = [:]
    public var minWindowSize: CGFloat = 300
    public var bsp = BspParams()
    public var stack = StackParams()
    public var scrolling = ScrollingParams()
    public var grid = GridParams()
    /// Drag-and-drop visuals (consumed once D&D lands).
    public var dragShowGhost = true
    public var dragShowDropZone = true

    public init() {}

    public func gaps(for space: SpaceID) -> Gaps {
        gapsOverride[space] ?? gapsGlobal
    }

    public func context(
        bounds: CGRect,
        space: Space
    ) -> LayoutContext {
        LayoutContext(
            bounds: bounds,
            gaps: gaps(for: space.id),
            focused: space.focused,
            minWindowSize: minWindowSize,
            bsp: bsp,
            stack: stack,
            scrolling: scrolling,
            grid: grid
        )
    }
}

/// Applies calculated layouts to real windows.
///
/// Consumes the current state, runs the layout engine for the
/// active space, and animates windows to their target frames.
/// Everything runs in AX coordinates.
@MainActor
public final class TilingEngine {
    public let animation = AnimationEngine()
    public var settings = TilingSettings()

    /// `set_space_animation`: animate windows flying in from
    /// the stash corner on a virtual space switch. Off by
    /// default — many simultaneous long-distance animations
    /// mean one blocking AX call per window per tick, which
    /// stutters on slow AX responders (Electron/WebKit).
    public var animateSpaceSwitch = false

    /// `set_mouse_resize`: what resizing a tiled window with
    /// the mouse does (applied on release).
    public var mouseResize: MouseResizeMode = .layout

    /// Applies frames off the main thread with frame-dropping
    /// and per-app EnhancedUserInterface toggling.
    private let applier = FrameApplier()

    /// Resolves the AX element of a window (wired to the
    /// event loop's registry).
    public var elementProvider: @MainActor (WindowID) -> AXUIElement? = { _ in
        nil
    }

    public init() {
        applier.elementProvider = { [weak self] id in
            self?.elementProvider(id)
        }
        animation.apply = { [applier] id, frame, setSize in
            applier.apply(id, frame, setSize: setSize)
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
            .displaysChanged:
            return true
        case .appLaunched, .windowFocused, .windowMoved,
            .windowResized, .windowTitleChanged,
            .nativeSpaceChanged:
            return false
        }
    }

    /// The frames the active space's layout assigns right
    /// now, without applying them. Used by retiling and by
    /// drag-and-drop slot detection.
    public func calculatedFrames(
        state: StateCoordinator
    ) -> [WindowID: CGRect] {
        guard
            let spaceID = state.workspaces.activeSpace,
            let space = state.workspaces[spaceID],
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else { return [:] }
        let bounds = GeometryUtils.axVisibleFrame(of: screen)
        let tiled = space.windows.filter { id in
            state.windows[id]?.isFloating == false
        }
        return LayoutEngine.calculate(
            mode: space.mode,
            windows: tiled,
            context: settings.context(
                bounds: bounds,
                space: space
            )
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
        force: Bool = false
    ) {
        guard
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else { return }
        let frames = calculatedFrames(state: state)

        for (id, target) in frames {
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
            if animated {
                animation.animate(
                    window: id,
                    on: screen,
                    from: current,
                    to: target
                )
            } else {
                animation.cancel(window: id)
                setFrame(id, target)
            }
        }
        stashInactive(
            state: state,
            fallback: screen,
            force: force
        )
    }

    // MARK: - Hiding inactive virtual spaces

    /// Visible sliver of stashed windows: macOS rejects fully
    /// offscreen frames, so this many points stay on screen.
    nonisolated static let stashPeek: CGFloat = 8

    /// Where a hidden window parks: the bottom-right corner
    /// of its screen, AeroSpace style (only the top-left
    /// `stashPeek` corner remains visible). Size unchanged.
    nonisolated static func stashFrame(
        _ frame: CGRect,
        in bounds: CGRect
    ) -> CGRect {
        CGRect(
            x: bounds.maxX - stashPeek,
            y: bounds.maxY - stashPeek,
            width: frame.width,
            height: frame.height
        )
    }

    /// Hides the tiled windows of every inactive virtual
    /// space. Floating windows (incl. PIP) are left alone —
    /// they behave as pinned across virtual spaces. Windows
    /// come back through the normal retile when their space
    /// is activated again.
    private func stashInactive(
        state: StateCoordinator,
        fallback: NSScreen,
        force: Bool
    ) {
        guard let active = state.workspaces.activeSpace
        else { return }
        for space in state.workspaces.allSpaces
        where space.id != active {
            for id in space.windows {
                guard let window = state.windows[id],
                    !window.isFloating
                else { continue }
                let screen =
                    NSScreen.screens.first {
                        GeometryUtils.axVisibleFrame(of: $0)
                            .intersects(window.frame)
                    } ?? fallback
                let target = Self.stashFrame(
                    window.frame,
                    in: GeometryUtils.axVisibleFrame(
                        of: screen
                    )
                )
                if !force,
                    Self.close(window.frame, to: target)
                {
                    continue
                }
                animation.cancel(window: id)
                setFrame(id, target)
            }
        }
    }

    /// Frames within this distance per edge count as "already
    /// there". Covers rounding and small app-side clamping.
    private static let retileTolerance: CGFloat = 2

    private static func close(
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
    public func setFrame(_ id: WindowID, _ frame: CGRect) {
        applier.apply(id, frame, setSize: true)
    }
}
