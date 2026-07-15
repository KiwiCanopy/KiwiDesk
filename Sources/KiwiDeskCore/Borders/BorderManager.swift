import AppKit

/// Keeps focus-border overlays in sync with the windows that
/// should wear a ring (#278). The driver (`KiwiCore.updateBorders`)
/// computes the desired set; this manager creates, updates, and
/// retires one `BorderOverlay` per window, keyed by `WindowID` —
/// mirroring `AppBarManager`'s diff-sync.
///
/// Two entry points: `sync` for steady state (create / recolor /
/// destroy), and `follow` for the animation hot path (move an
/// existing ring to a fresh window frame, no create / destroy).
@MainActor
public final class BorderManager {
    /// One window's desired ring. Frames are in AX coordinates,
    /// taken from cached window state — never a live AX call.
    public struct Spec: Equatable {
        public let window: WindowID
        public let frame: CGRect
        public let colorHex: String
        public let width: CGFloat
        public let cornerStyle: BorderStyle.CornerStyle

        public init(
            window: WindowID,
            frame: CGRect,
            colorHex: String,
            width: CGFloat,
            cornerStyle: BorderStyle.CornerStyle
        ) {
            self.window = window
            self.frame = frame
            self.colorHex = colorHex
            self.width = width
            self.cornerStyle = cornerStyle
        }
    }

    private var overlays: [WindowID: BorderOverlay] = [:]
    /// Last synced spec per window, so the per-tick `follow` can
    /// recompute geometry from a fresh frame while reusing the
    /// window's color / width / corner style.
    private var specs: [WindowID: Spec] = [:]

    public init() {}

    /// Windows currently wearing a ring — the manager's contract
    /// surface for tests and diagnostics.
    public var borderedWindows: Set<WindowID> {
        Set(overlays.keys)
    }

    /// Shows exactly `desired` — one ring per window — and retires
    /// the overlays of any window no longer in the set (an empty
    /// array retires them all).
    public func sync(_ desired: [Spec]) {
        let wanted = Set(desired.map(\.window))
        for (id, overlay) in overlays where !wanted.contains(id) {
            overlay.hide()
            overlays[id] = nil
            specs[id] = nil
        }
        for spec in desired {
            specs[spec.window] = spec
            overlay(for: spec.window).update(
                geometry: geometry(spec, frame: spec.frame),
                colorHex: spec.colorHex,
                screen: screen(for: spec.frame)
            )
        }
    }

    /// Animation hot path: move an already-shown ring to track its
    /// window's current frame. A no-op for windows without a ring
    /// (unbordered, or the sync hasn't run yet).
    public func follow(_ id: WindowID, windowFrame: CGRect) {
        guard let overlay = overlays[id], let spec = specs[id]
        else { return }
        overlay.update(
            geometry: geometry(spec, frame: windowFrame),
            colorHex: spec.colorHex,
            screen: screen(for: windowFrame)
        )
    }

    /// Retires every ring (display sleep, native-space switch).
    public func clear() {
        for overlay in overlays.values { overlay.hide() }
        overlays = [:]
        specs = [:]
    }

    private func geometry(
        _ spec: Spec,
        frame: CGRect
    ) -> BorderGeometry {
        BorderGeometry.compute(
            windowFrame: frame,
            width: spec.width,
            cornerStyle: spec.cornerStyle
        )
    }

    private func overlay(for window: WindowID) -> BorderOverlay {
        if let existing = overlays[window] { return existing }
        let overlay = BorderOverlay()
        overlays[window] = overlay
        return overlay
    }

    /// The screen a window's frame center sits on (for the ring's
    /// pixel scale), or the main screen. AX coords, so flip the
    /// center before the Cocoa hit test.
    private func screen(for frame: CGRect) -> NSScreen? {
        let center = GeometryUtils.axPoint(
            CGPoint(x: frame.midX, y: frame.midY)
        )
        return NSScreen.screens.first {
            $0.frame.contains(center)
        } ?? NSScreen.main
    }
}
