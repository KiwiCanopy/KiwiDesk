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
        /// Whether this ring wears the glow bloom (#358). Set only on
        /// the focused ring — `borderSpecs` never glows an unfocused
        /// ring, so this is `false` for every non-focused spec.
        public let glow: Bool

        public init(
            window: WindowID,
            frame: CGRect,
            colorHex: String,
            width: CGFloat,
            cornerStyle: BorderStyle.CornerStyle,
            glow: Bool = false
        ) {
            self.window = window
            self.frame = frame
            self.colorHex = colorHex
            self.width = width
            self.cornerStyle = cornerStyle
            self.glow = glow
        }
    }

    // `overlays` and the SkyLight tracking state below are read and
    // written by the WindowServer integration in the
    // `BorderManager+SkyLight` extension (separate file), so they are
    // internal rather than private.
    var overlays: [WindowID: BorderOverlay] = [:]
    /// Transient rings spawned only to carry the dead-end bounce on
    /// a window that has no steady-state ring (borders off). Kept
    /// out of `overlays` so `sync` never sees them; torn down by the
    /// bump animator's completion (`+DeadEnd`).
    var bumpTransients: [WindowID: BorderOverlay] = [:]
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
    /// each rebuilds for the new order at the next `sync`. Both
    /// orders now prefer the SkyLight backend (below-order too);
    /// AppKit is only the availability/failure fallback.
    private var activeOrder: BorderGeometry.Order = .below
    var eventSource: SkyLightWindowEvents?
    var triedEventSource = false
    var privateRuntimeStarted = false
    var skyLightActive = false
    var reportedTrackingActive: Bool?
    var onLog: @MainActor (String) -> Void = { _ in }
    /// Tee of every WindowServer bounds re-read (`reconcile`) —
    /// the live-tracking hot path AX echoes lag behind. Wired
    /// to the sticky mark so it follows a dragged window at
    /// WS event rate, exactly like the ring (QA 2026-07-21);
    /// a no-op by default.
    var onFrameReconciled: @MainActor (WindowID, CGRect) -> Void = { _, _ in }
    /// Tee of every WindowServer z-order change (`.reorder` /
    /// `.level`). Wired to the sticky mark so it re-asserts its
    /// stacking whenever the target raises — a re-click on an
    /// ALREADY-focused window raises it above its own mark yet
    /// fires no AX focus event, so the focus-driven re-sync never
    /// runs (owner QA 2026-07-21). A no-op by default.
    var onWindowReordered: @MainActor (WindowID) -> Void = { _ in }
    /// Windows the sticky mark needs WS z-order events for, even
    /// when they wear no ring (borders off / unfocused). Folded
    /// into the WS watch set so the reorder tee reaches them.
    var stickyTracked: Set<WindowID> = []

    /// Drives the dead-end rubber-band (#436). Owned here because it
    /// bumps the same overlays this manager holds, and spawns a
    /// transient one when borders are off (see `+DeadEnd`).
    let bumpAnimator = BorderBumpAnimator()

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
    /// live overlay so the next `sync` rebuilds it for the new
    /// order. Both orders prefer the SkyLight backend (front =
    /// above-order, behind = below-order); AppKit renders only when
    /// SkyLight is unavailable. Per-window `specs` and cached radii
    /// are kept — only the geometry/stacking changes.
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
                screen: screen(for: spec.frame),
                glow: spec.glow
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
            glow: spec.glow,
            restoreVisibility: restoreVisibility
        )
    }

    /// The window's real corner radius so the ring's arc hugs it,
    /// resolved once and cached (#357). Falls back to the shared
    /// default when SkyLight reports none — that default is cached
    /// too, so a radius-less window isn't re-queried on every sync.
    func cornerRadius(for id: WindowID) -> CGFloat {
        if let cached = cornerRadii[id] { return cached }
        let resolved =
            SkyLight.windowCornerRadius(id.raw)
            ?? GeometryUtils.systemWindowCornerRadius
        cornerRadii[id] = resolved
        return resolved
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
        onFrameReconciled(id, frame)
        return true
    }

    /// Retires every ring at once. Used on shutdown (`stop()`)
    /// before the quit gather scatters windows; steady-state
    /// retirement of individual rings goes through `sync`.
    public func clear() {
        bumpAnimator.flushAll()
        for overlay in overlays.values { overlay.hide() }
        for overlay in bumpTransients.values { overlay.hide() }
        overlays = [:]
        bumpTransients = [:]
        specs = [:]
        cornerRadii = [:]
        stickyTracked = []
        _ = eventSource?.watch([])
    }

    /// Force-settles in-flight dead-end bounces on a display change:
    /// a bump whose monitor was unplugged would otherwise stall (its
    /// DisplayLink stops firing) and leak its transient overlay.
    func displaysChanged() {
        bumpAnimator.flushAll()
    }

    /// Drops a window's cached corner radius. Narrow surface for the
    /// dead-end cue's transient teardown (`+DeadEnd`) so a borders-off
    /// window that only ever bounced doesn't keep a stale radius until
    /// `clear()` — which would mis-round a later ring if the id is
    /// recycled (#308). No-op'd when a steady ring still owns it.
    func forgetCornerRadius(_ id: WindowID) {
        cornerRadii[id] = nil
    }

    private func overlay(for window: WindowID) -> BorderOverlay {
        if let existing = overlays[window] { return existing }
        let overlay = makeOverlay(for: window)
        overlays[window] = overlay
        return overlay
    }

    /// Builds a ring overlay for `window` without inserting it into
    /// the steady-state `overlays` store. Used there via
    /// `overlay(for:)`, and by the dead-end cue's transient overlay
    /// (`+DeadEnd`), which lives in a separate store so a concurrent
    /// `sync` can never adopt or stomp it (and vice-versa).
    func makeOverlay(for window: WindowID) -> BorderOverlay {
        BorderOverlay(
            window: window.raw,
            // Below-order stays the default (#361) and now prefers
            // the space-pinned SkyLight path: Mission Control
            // leaves a pinned ring behind instantly (jankyborders'
            // model), and a below ring skips the above-order
            // sub-level re-assertion that flickered under the
            // per-keystroke compositor churn Firefox/Zen emit —
            // the target itself occludes it. AppKit is now purely
            // the fallback when the private surface is unavailable
            // or fails. `border.set_draw_order("front")` opts into
            // the SkyLight above-order path (#367); `activeOrder`
            // carries that choice. WS geometry tracking is
            // unaffected (see `usesWindowServerTracking`).
            order: activeOrder,
            onFallback: { [weak self] reason in
                self?.onLog(
                    "border \(window.raw): \(reason); "
                        + "using AppKit rendering"
                )
            }
        )
    }

    /// The screen a window's frame mostly sits on (for the ring's
    /// pixel scale), or the main screen. Max visible-area overlap
    /// (#449), not a center hit test: a frame hanging off an edge
    /// (stash corner, mid-drag) keeps an offscreen center yet
    /// still resolves its OWN display's scale.
    func screen(for frame: CGRect) -> NSScreen? {
        TilingEngine.screen(containing: frame) ?? NSScreen.main
    }
}
