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
    /// Each window's real corner radius, resolved once per window and
    /// reused. A window's radius is a fixed OS attribute, and a query
    /// that comes back empty (a square/borderless window reporting no
    /// radius) is a permanent answer, not a transient one — so a
    /// resolved default is cached too, never re-queried every sync.
    private var cornerRadii: [WindowID: CGFloat] = [:]
    /// The draw order every ring is currently built for (#367).
    /// Global, not per-window: flipping it retires all overlays so
    /// each rebuilds on the matching backend (below → AppKit,
    /// above → SkyLight) at the next `sync`.
    private var activeOrder: BorderGeometry.Order = .below
    private var eventSource: SkyLightWindowEvents?
    private var triedEventSource = false
    private var privateRuntimeStarted = false
    private var skyLightActive = false
    private var reportedTrackingActive: Bool?
    var onLog: @MainActor (String) -> Void = { _ in }

    public init() {}

    /// Enables the private WindowServer fast path once KiwiDesk's
    /// application lifecycle has started. Keeping it dormant during
    /// pure core construction prevents tests and previews from
    /// registering process-global SkyLight callbacks.
    func start() {
        privateRuntimeStarted = true
    }

    /// Retires every ring and disables private callbacks until the
    /// next application start.
    func stop() {
        clear()
        privateRuntimeStarted = false
        skyLightActive = false
        reportedTrackingActive = nil
    }

    /// Windows currently wearing a ring — the manager's contract
    /// surface for tests and diagnostics.
    public var borderedWindows: Set<WindowID> {
        Set(overlays.keys)
    }

    /// Selects whether rings stack behind or in front of windows
    /// (#367). A no-op when unchanged; a real flip retires every
    /// live overlay so the next `sync` rebuilds it on the backend
    /// that matches the new order (front → SkyLight above-order,
    /// behind → AppKit below-order). Per-window `specs` and cached
    /// radii are kept — only the render backend changes.
    public func setDrawOrder(_ order: BorderStyle.DrawOrder) {
        let mapped: BorderGeometry.Order =
            order == .front ? .above : .below
        guard mapped != activeOrder else { return }
        for overlay in overlays.values { overlay.hide() }
        overlays.removeAll()
        activeOrder = mapped
    }

    /// Shows exactly `desired` — one ring per window — and retires
    /// the overlays of any window no longer in the set (an empty
    /// array retires them all).
    public func sync(_ desired: [Spec]) {
        let wanted = Set(desired.map(\.window))
        updateSkyLightSubscription(wanted)
        for (id, overlay) in overlays where !wanted.contains(id) {
            overlay.hide()
            overlays[id] = nil
            specs[id] = nil
            cornerRadii[id] = nil
        }
        for spec in desired {
            specs[spec.window] = spec
            let overlay = overlay(for: spec.window)
            overlay.update(
                frame: spec.frame,
                width: spec.width,
                cornerStyle: spec.cornerStyle,
                cornerRadius: cornerRadius(for: spec.window),
                colorHex: spec.colorHex,
                screen: screen(for: spec.frame)
            )
            // Re-assert stacking each sync (focus change, retile,
            // z-order restore) — the target may have moved in the
            // window order since the ring last positioned.
            overlay.order(relativeTo: spec.window.raw)
        }
    }

    /// Animation / AX-echo hot path: move an already-shown ring to
    /// a window's current frame — UNLESS the WindowServer event
    /// stream is already tracking it, since a coalesced AX echo
    /// would rewind the ring behind the live WS bounds. This one
    /// guard is the whole invariant, so no caller can forget it
    /// (was hand-mirrored across three call sites). A no-op for
    /// windows without a ring.
    public func follow(_ id: WindowID, windowFrame: CGRect) {
        guard !usesWindowServerTracking(id) else { return }
        apply(id, windowFrame: windowFrame)
    }

    /// Unguarded reposition — the WS bounds re-read (`reconcile`)
    /// and the steady-state `sync` own the ring's frame directly,
    /// so they bypass the WS-tracking guard on `follow`.
    private func apply(
        _ id: WindowID,
        windowFrame: CGRect,
        restoreVisibility: Bool = false
    ) {
        guard let overlay = overlays[id], let spec = specs[id]
        else { return }
        overlay.update(
            frame: windowFrame,
            width: spec.width,
            cornerStyle: spec.cornerStyle,
            cornerRadius: cornerRadius(for: id),
            colorHex: spec.colorHex,
            screen: screen(for: windowFrame),
            restoreVisibility: restoreVisibility
        )
    }

    /// The window's real corner radius so the ring's arc hugs it,
    /// resolved once and cached (#357). Falls back to the shared
    /// default when SkyLight reports none — that default is cached
    /// too, so a radius-less window isn't re-queried on every sync.
    private func cornerRadius(for id: WindowID) -> CGFloat {
        if let cached = cornerRadii[id] { return cached }
        let resolved =
            SkyLight.windowCornerRadius(id.raw)
            ?? GeometryUtils.systemWindowCornerRadius
        cornerRadii[id] = resolved
        return resolved
    }

    /// Geometry tracking is independent of rendering. If a raw SLS
    /// window falls back to AppKit, that panel can still follow real
    /// bounds from a healthy WindowServer event stream.
    func usesWindowServerTracking(_ id: WindowID) -> Bool {
        overlays[id] != nil && skyLightActive
    }

    /// Re-reads the authoritative WindowServer bounds after a mouse
    /// drag. Floating windows do not retile, so their final ring must
    /// be reconciled explicitly on button-up.
    @discardableResult
    func reconcile(
        _ id: WindowID,
        restoreVisibility: Bool = true
    ) -> Bool {
        guard let connection = SkyLight.connection,
            let getBounds = SkyLight.getWindowBounds
        else { return false }
        var frame = CGRect.zero
        guard
            getBounds(connection, id.raw, &frame) == .success
        else { return false }
        apply(
            id,
            windowFrame: frame,
            restoreVisibility: restoreVisibility
        )
        return true
    }

    /// Retires every ring at once. Used on shutdown (`stop()`)
    /// before the quit gather scatters windows; steady-state
    /// retirement of individual rings goes through `sync`.
    public func clear() {
        for overlay in overlays.values { overlay.hide() }
        overlays = [:]
        specs = [:]
        cornerRadii = [:]
        _ = eventSource?.watch([])
    }

    private func overlay(for window: WindowID) -> BorderOverlay {
        if let existing = overlays[window] { return existing }
        let overlay = BorderOverlay(
            window: window.raw,
            // Below-order (AppKit) is the default (#361): its
            // `order(.below)` re-stack is flicker-free — unlike the
            // SkyLight above-order transaction — so it holds steady
            // under the per-keystroke compositor churn Firefox/Zen
            // emit, and with each window's real radius the corner hugs
            // cleanly. `border.set_draw_order("front")` opts into the
            // crisp SkyLight above-order path (#367); `activeOrder`
            // carries that choice. WS geometry tracking is unaffected
            // (see `usesWindowServerTracking`).
            order: activeOrder,
            onFallback: { [weak self] reason in
                self?.onLog(
                    "border \(window.raw): \(reason); "
                        + "using AppKit rendering"
                )
            }
        )
        overlays[window] = overlay
        return overlay
    }

    /// Receives the WindowServer notifications registered by
    /// `SkyLightWindowEvents`. Bounds are read from SkyLight's cache,
    /// never AX, then fed through the same geometry path as animation
    /// and cursor following.
    func handleSkyLightEvent(
        _ kind: SkyLightWindowEvents.Kind,
        window id: WindowID
    ) {
        guard let overlay = overlays[id] else { return }
        switch kind.action {
        case .follow:
            _ = reconcile(id)
        case .reorder:
            overlay.order(relativeTo: id.raw)
        case .followAndReorder:
            // Unhide must re-assert order even when the bounds read
            // fails. Leave restoration to that one explicit order so
            // a successful reconcile cannot issue it twice.
            _ = reconcile(id, restoreVisibility: false)
            overlay.order(relativeTo: id.raw)
        case .hide:
            overlay.hide()
        }
    }

    private func updateSkyLightSubscription(
        _ wanted: Set<WindowID>
    ) {
        guard privateRuntimeStarted else {
            skyLightActive = false
            return
        }
        if !triedEventSource, !wanted.isEmpty {
            triedEventSource = true
            eventSource = SkyLightWindowEvents.shared
            eventSource?.attach(self)
        }
        let wasActive = skyLightActive
        skyLightActive = eventSource?.watch(wanted) == true
        if reportedTrackingActive != skyLightActive {
            reportedTrackingActive = skyLightActive
            let mode =
                skyLightActive
                ? "WindowServer border tracking active"
                : "WindowServer border tracking unavailable; "
                    + "using AX fallback"
            onLog(mode)
        }
        if wasActive, !skyLightActive {
            for overlay in overlays.values {
                overlay.useAppKitFallback()
            }
        }
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
