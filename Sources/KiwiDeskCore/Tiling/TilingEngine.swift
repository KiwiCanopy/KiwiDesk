import AppKit
import ApplicationServices
import CoreGraphics

/// Tunable tiling parameters (later fed from init.lua).
public struct TilingSettings: Sendable {
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

    /// Resolves the AX element of a window (wired to the
    /// event loop's registry).
    public var elementProvider: @MainActor (WindowID) -> AXUIElement? = { _ in
        nil
    }

    public init() {
        animation.apply = { [weak self] id, frame in
            guard let element = self?.elementProvider(id)
            else { return }
            WindowControl.setFrame(frame, of: element)
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

    /// Recomputes and applies the active space's layout.
    public func retile(state: StateCoordinator) {
        guard
            let spaceID = state.workspaces.activeSpace,
            let space = state.workspaces[spaceID],
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else { return }

        let bounds = GeometryUtils.axVisibleFrame(of: screen)
        let tiled = space.windows.filter { id in
            state.windows[id]?.isFloating == false
        }
        let frames = LayoutEngine.calculate(
            mode: space.mode,
            windows: tiled,
            context: settings.context(
                bounds: bounds,
                space: space
            )
        )

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
}
