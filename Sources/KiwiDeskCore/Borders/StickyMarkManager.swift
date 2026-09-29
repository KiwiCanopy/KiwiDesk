import AppKit
import CoreGraphics

/// Manages the on-window state marks (#414): sticky and, since
/// #1799, floating — one plate per window, sticky outermost
/// (`BorderManager`).
@MainActor
public final class StickyMarkManager {
    /// One glyph on a window's plate.
    public struct Glyph: Equatable {
        public enum Kind: Equatable {
            case sticky
            case floating
        }

        public let kind: Kind
        /// SF Symbol name (`infinity` / `pin.fill`, #445;
        /// `FloatingStyle.symbolName`).
        public let symbolName: String
        /// Hex color string; empty = automatic (#429).
        public let color: String

        public static func sticky(
            _ symbolName: String = StickyStyle.symbolName,
            color: String = ""
        ) -> Glyph {
            Glyph(kind: .sticky, symbolName: symbolName, color: color)
        }

        public static func floating(color: String = "") -> Glyph {
            Glyph(
                kind: .floating,
                symbolName: FloatingStyle.symbolName,
                color: color
            )
        }
    }

    /// Window mark specification.
    public struct Spec: Equatable {
        public let window: WindowID
        public let frame: CGRect
        /// Outermost first: sticky, then floating (#1799).
        public let glyphs: [Glyph]
        /// Liquid Glass as drawn — the stored leaf through
        /// `LiquidGlassGate` (#1621).
        public let glass: Bool

        public init(
            window: WindowID,
            frame: CGRect,
            glyphs: [Glyph] = [.sticky()],
            glass: Bool
        ) {
            self.window = window
            self.frame = frame
            self.glyphs = glyphs
            self.glass = glass
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

    /// Windows currently displaying a mark.
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
            overlay.setGlass(spec.glass)
            overlay.setGlyphs(spec.glyphs)
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
    /// window with no sticky glyph silently draws nothing — the
    /// pills are sticky's (#1799) — and the refusal's sound
    /// follows the drawing.
    @discardableResult
    public func flash(
        _ id: WindowID,
        format: String,
        mark: SpaceMark,
        delay: TimeInterval
    ) -> Bool {
        guard let overlay = overlays[id], overlay.isSticky else {
            return false
        }
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
