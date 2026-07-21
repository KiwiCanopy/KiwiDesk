import AppKit
import CoreGraphics

/// Keeps one sticky-mark chip per sticky window (#414),
/// mirroring `BorderManager`'s diff-sync at marker scale: `sync`
/// for steady state (create / move / retire), `follow` for the
/// move/animation hot path. Driven by
/// `KiwiCore.updateStickyIndicators()` inside `retile()`.
@MainActor
public final class StickyIndicatorManager {
    /// One window's desired mark. Frames are AX coordinates
    /// from cached window state — never a live AX call.
    public struct Spec: Equatable {
        public let window: WindowID
        public let frame: CGRect

        public init(window: WindowID, frame: CGRect) {
            self.window = window
            self.frame = frame
        }
    }

    private var overlays: [WindowID: StickyIndicatorOverlay] =
        [:]

    public init() {}

    /// Windows currently wearing the mark — the contract
    /// surface for tests and diagnostics.
    public var markedWindows: Set<WindowID> {
        Set(overlays.keys)
    }

    /// Shows exactly `desired` — one chip per sticky window —
    /// and retires the chips of any window no longer in the set.
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
                ?? StickyIndicatorOverlay(
                    window: spec.window.raw
                )
            overlays[spec.window] = overlay
            overlay.update(frame: spec.frame)
            // Re-assert stacking each sync (focus change,
            // retile, z-order restore) — never per follow
            // tick (the chip lags otherwise).
            overlay.order()
        }
    }

    /// Move/animation hot path: re-corner an already-shown chip
    /// on a fresh window frame. A no-op for unmarked windows.
    public func follow(_ id: WindowID, windowFrame: CGRect) {
        overlays[id]?.update(frame: windowFrame)
    }

    /// Retires every chip at once (shutdown).
    public func clear() {
        for overlay in overlays.values { overlay.hide() }
        overlays = [:]
    }
}
