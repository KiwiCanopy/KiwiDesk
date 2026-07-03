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
    /// applying frames emits them, which would loop.
    public nonisolated static func shouldRetile(
        after event: KiwiEvent
    ) -> Bool {
        switch event {
        case .windowCreated, .windowDestroyed, .appTerminated,
            .windowFocused, .displaysChanged:
            return true
        case .appLaunched, .windowMoved, .windowResized,
            .windowTitleChanged:
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
    public func retile(state: StateCoordinator) {
        guard
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else { return }
        let frames = calculatedFrames(state: state)

        for (id, target) in frames {
            guard let current = state.windows[id]?.frame
            else { continue }
            guard current != target else {
                animation.cancel(window: id)
                continue
            }
            animation.animate(
                window: id,
                on: screen,
                from: current,
                to: target
            )
        }
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
