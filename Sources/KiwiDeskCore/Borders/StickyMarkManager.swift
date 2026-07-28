import AppKit
import CoreGraphics

/// Keeps one sticky mark per sticky window (#414),
/// mirroring `BorderManager`'s diff-sync at marker scale: `sync`
/// for steady state (create / move / retire), `follow` for the
/// move/animation hot path. Driven by
/// `KiwiCore.updateStickyMarks()` inside `retile()`.
@MainActor
public final class StickyMarkManager {
    /// One window's desired mark. Frames are AX coordinates
    /// from cached window state — never a live AX call.
    public struct Spec: Equatable {
        public let window: WindowID
        public let frame: CGRect
        /// The mark tint as raw hex (#429); empty = "Automatic"
        /// (adaptive `.labelColor`). Resolved at the plate via
        /// `NSColor.mark` so the mark and the Space Bar sticky
        /// badge read the one `StickyStyle.color`.
        public let color: String
        /// The SF Symbol for this window's sticky SCOPE (#445):
        /// `infinity` for global, `pin.fill` for display. Carried
        /// per-window because one mark manager serves both kinds.
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

    /// Whether the WindowServer stream already tracks this window's
    /// frame — wired to `BorderManager.markUsesWindowServerTracking`.
    /// When true, `follow` (the AX-echo / animation path) stands
    /// down so a coalesced echo can't rewind the mark behind the
    /// live WS bounds (the ring's `follow` guard, mirrored). A no-op
    /// default keeps the manager testable in isolation.
    public var isWindowServerTracked: @MainActor (WindowID) -> Bool = { _ in
        false
    }

    /// Whether OUR OWN animation currently drives this window —
    /// wired to `AnimationEngine.isAnimating` (the ring's guard,
    /// mirrored, #594). While true the per-tick commanded frame
    /// owns the mark, so the AX-echo `follow` stands down; the
    /// WS `reposition` tee already stands down upstream (the
    /// ring's `reconcile` gate). A no-op default keeps the
    /// manager testable in isolation.
    public var isAnimating: @MainActor (WindowID) -> Bool = { _ in
        false
    }

    public init() {}

    /// Windows currently wearing the mark — the contract
    /// surface for tests and diagnostics.
    public var markedWindows: Set<WindowID> {
        Set(overlays.keys)
    }

    /// The frame a window's mark last positioned against, for
    /// tests that need to prove `follow` stood down (or didn't).
    public func lastFrame(_ id: WindowID) -> CGRect? {
        overlays[id]?.lastFrame
    }

    /// Shows exactly `desired` — one mark per sticky window —
    /// and retires the marks of any window no longer in the set.
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
            // Geometry stands down mid-animation (#596) — the
            // same call the ring's `sync` makes, not a mirror of
            // it. Colour, symbol, stacking and retirement are
            // unaffected.
            overlay.update(
                frame: FollowSource.syncFrame(
                    spec: spec.frame,
                    held: overlay.lastFrame,
                    animating: isAnimating(spec.window)
                )
            )
            // Re-assert stacking each sync (focus change,
            // retile, z-order restore) — never per follow
            // tick (the mark lags otherwise).
            overlay.order()
        }
    }

    /// AX-echo / animation hot path: re-corner an already-shown
    /// mark on a fresh frame. The stand-down decision is
    /// `FollowSource.applies` — one switch shared with the ring,
    /// so the two overlays cannot drift (#285/#594). A no-op for
    /// unmarked windows.
    public func follow(
        _ id: WindowID,
        windowFrame: CGRect,
        source: FollowSource
    ) {
        guard
            source.applies(
                wsTracked: isWindowServerTracked(id),
                animating: isAnimating(id)
            )
        else { return }
        overlays[id]?.update(frame: windowFrame)
    }

    /// Unguarded reposition — the WindowServer bounds re-read
    /// (`onFrameReconciled`) owns the mark's frame directly, so it
    /// bypasses the WS-tracking guard on `follow` (the ring's
    /// `apply`, mirrored). A no-op for unmarked windows.
    public func reposition(_ id: WindowID, windowFrame: CGRect) {
        overlays[id]?.update(frame: windowFrame)
    }

    /// Re-asserts a mark's stacking above its target after a
    /// WindowServer z-order change (`onWindowReordered`): a
    /// re-click raises the window above its own mark yet fires no
    /// AX focus event, so this is the only re-assert that path
    /// gets (#414 QA). A no-op for unmarked windows.
    public func reassert(_ id: WindowID) {
        overlays[id]?.order()
    }

    /// Briefly expands a window's mark into a pill showing its
    /// home-space reorder hint (`format` with the space's `mark`
    /// substituted), then auto-collapses (#421) — the friction-
    /// moment cue when a tiled-sticky traveler snaps back on a
    /// foreign space. A no-op for unmarked windows.
    public func flash(
        _ id: WindowID,
        format: String,
        mark: SpaceMark,
        delay: TimeInterval
    ) {
        overlays[id]?.flash(
            format: format,
            mark: mark,
            delay: delay
        )
    }

    /// Retires every mark at once (shutdown).
    public func clear() {
        for overlay in overlays.values { overlay.hide() }
        overlays = [:]
    }
}
