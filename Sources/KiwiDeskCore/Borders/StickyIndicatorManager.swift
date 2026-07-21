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

    /// Whether the WindowServer stream already tracks this window's
    /// frame — wired to `BorderManager.chipUsesWindowServerTracking`.
    /// When true, `follow` (the AX-echo / animation path) stands
    /// down so a coalesced echo can't rewind the chip behind the
    /// live WS bounds (the ring's `follow` guard, mirrored). A no-op
    /// default keeps the manager testable in isolation.
    public var isWindowServerTracked: @MainActor (WindowID) -> Bool = { _ in
        false
    }

    public init() {}

    /// Windows currently wearing the mark — the contract
    /// surface for tests and diagnostics.
    public var markedWindows: Set<WindowID> {
        Set(overlays.keys)
    }

    /// The frame a window's chip last positioned against, for
    /// tests that need to prove `follow` stood down (or didn't).
    public func lastFrame(_ id: WindowID) -> CGRect? {
        overlays[id]?.lastFrame
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

    /// AX-echo / animation hot path: re-corner an already-shown
    /// chip on a fresh frame — UNLESS the WindowServer stream
    /// already tracks it, since a coalesced AX echo would rewind
    /// the chip behind the live WS bounds (the ring's `follow`
    /// guard, mirrored). A no-op for unmarked windows.
    public func follow(_ id: WindowID, windowFrame: CGRect) {
        guard !isWindowServerTracked(id) else { return }
        overlays[id]?.update(frame: windowFrame)
    }

    /// Unguarded reposition — the WindowServer bounds re-read
    /// (`onFrameReconciled`) owns the chip's frame directly, so it
    /// bypasses the WS-tracking guard on `follow` (the ring's
    /// `apply`, mirrored). A no-op for unmarked windows.
    public func reposition(_ id: WindowID, windowFrame: CGRect) {
        overlays[id]?.update(frame: windowFrame)
    }

    /// Re-asserts a chip's stacking above its target after a
    /// WindowServer z-order change (`onWindowReordered`): a
    /// re-click raises the window above its own chip yet fires no
    /// AX focus event, so this is the only re-assert that path
    /// gets (#414 QA). A no-op for unmarked windows.
    public func reassert(_ id: WindowID) {
        overlays[id]?.order()
    }

    /// Retires every chip at once (shutdown).
    public func clear() {
        for overlay in overlays.values { overlay.hide() }
        overlays = [:]
    }
}
