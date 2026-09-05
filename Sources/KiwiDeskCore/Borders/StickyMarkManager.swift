import AppKit
import CoreGraphics

/// Manages sticky mark overlay indicators per sticky window
/// (#414, `BorderManager`).
@MainActor
public final class StickyMarkManager {
    /// Window mark specification.
    public struct Spec: Equatable {
        public let window: WindowID
        public let frame: CGRect
        /// Hex color string (`StickyStyle.color`, #429).
        public let color: String
        /// SF Symbol name for sticky scope (`infinity` / `pin.fill`, #445).
        public let symbolName: String

        public init(
            window: WindowID,
            frame: CGRect,
            color: String = "",
            symbolName: String = StickyStyle.symbolName
        ) {
            self.window = window
            self.frame = frame
            self.color = color
            self.symbolName = symbolName
        }
    }

    private var overlays: [WindowID: StickyMarkOverlay] =
        [:]

    /// Whether WindowServer stream tracks window
    /// (`BorderManager.markUsesWindowServerTracking`).
    public var isWindowServerTracked: @MainActor (WindowID) -> Bool = { _ in
        false
    }

    /// Whether active animation drives window
    /// (`AnimationEngine.isAnimating`, #594).
    public var isAnimating: @MainActor (WindowID) -> Bool = { _ in
        false
    }

    /// Engine's pending target frame (`KiwiCore+Bootstrap`, #881).
    public var commandedFrame: @MainActor (WindowID) -> CGRect? = {
        _ in nil
    }

    public init() {}

    /// Windows currently displaying a sticky mark.
    public var markedWindows: Set<WindowID> {
        Set(overlays.keys)
    }

    /// Frame used in the last positioning update.
    public func lastFrame(_ id: WindowID) -> CGRect? {
        overlays[id]?.lastFrame
    }

    /// Synchronizes visible marks to desired specs (#596).
    public func sync(_ desired: [Spec]) {
        let wanted = Set(desired.map(\.window))
        for (id, overlay) in overlays
        where !wanted.contains(id) {
            overlay.hide()
            overlays[id] = nil
        }
        for spec in desired {
            let overlay =
                overlays[spec.window]
                ?? StickyMarkOverlay(
                    window: spec.window.raw
                )
            overlays[spec.window] = overlay
            overlay.setMarkColor(spec.color)
            overlay.setSymbol(spec.symbolName)
            overlay.update(
                frame: FollowSource.syncFrame(
                    spec: spec.frame,
                    held: overlay.lastFrame,
                    animating: isAnimating(spec.window),
                    commanded: commandedFrame(spec.window)
                )
            )
            overlay.order()
        }
    }

    /// Follows moving/animating window frame
    /// (`FollowSource.renderFrame`, #285, #594, #677).
    public func follow(
        _ id: WindowID,
        windowFrame: CGRect,
        source: FollowSource,
        pin: SizePin?
    ) {
        guard
            let frame = source.renderFrame(
                reported: windowFrame,
                pin: pin,
                wsTracked: isWindowServerTracked(id),
                animating: isAnimating(id)
            )
        else { return }
        overlays[id]?.update(frame: frame)
    }

    /// Direct un-guarded reposition from reconciled bounds
    /// (`onFrameReconciled`).
    public func reposition(_ id: WindowID, windowFrame: CGRect) {
        overlays[id]?.update(frame: windowFrame)
    }

    /// Re-orders mark above window following z-order changes
    /// (`onWindowReordered`, #414).
    public func reassert(_ id: WindowID) {
        overlays[id]?.order()
    }

    /// Flashes expanded home-space reorder hint (#421).
    /// Returns whether a pill was actually DRAWN (#1255): a
    /// window with no mark overlay silently draws nothing, and
    /// the refusal's sound follows the drawing.
    @discardableResult
    public func flash(
        _ id: WindowID,
        format: String,
        mark: SpaceMark,
        delay: TimeInterval
    ) -> Bool {
        guard let overlay = overlays[id] else { return false }
        overlay.flash(
            format: format,
            mark: mark,
            delay: delay
        )
        return true
    }

    /// Removes and hides all active marks.
    public func clear() {
        for overlay in overlays.values { overlay.hide() }
        overlays = [:]
    }
}
