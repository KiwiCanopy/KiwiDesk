import AppKit

/// Keeps focus-border overlays in sync with targeted windows (#278).
@MainActor
public final class BorderManager {
    /// One window's desired ring specification in AX coordinates.
    public struct Spec: Equatable {
        public let window: WindowID
        public let frame: CGRect
        public let colorHex: String
        public let width: CGFloat
        public let cornerStyle: BorderStyle.CornerStyle
        /// Resolved glow blur radius (0 = none, #358, #551).
        public let glowBlur: CGFloat
        /// The stroke's sheen strength (#1644), 0 for none.
        public let sheen: CGFloat

        public init(
            window: WindowID,
            frame: CGRect,
            colorHex: String,
            width: CGFloat,
            cornerStyle: BorderStyle.CornerStyle,
            glowBlur: CGFloat = 0,
            sheen: CGFloat = 0
        ) {
            self.window = window
            self.frame = frame
            self.colorHex = colorHex
            self.width = width
            self.cornerStyle = cornerStyle
            self.glowBlur = glowBlur
            self.sheen = sheen
        }
    }

    var overlays: [WindowID: BorderOverlay] = [:]
    /// Rings `sync` retired, kept invisible until their window
    /// wears one again: a Space switch then creates and orders out
    /// no panel (#1925). Pruned once the window is gone.
    var dormant: [WindowID: BorderOverlay] = [:]
    /// Transient rings spawned for dead-end bounces when borders are disabled.
    var bumpTransients: [WindowID: BorderOverlay] = [:]
    #if DEBUG
        /// Test-only: hears every dead-end cue asked for, ahead of
        /// the runtime gate a test core never passes. Production
        /// must not read it; it says nothing about a drawn bump.
        var deadEndProbe: ((WindowID, Direction) -> Void)?
    #endif
    #if DEBUG
        /// Test-only: whether the last `sync` re-stacked every
        /// ring. Production must not read it (#1925).
        var lastSyncReassertedOrder: Bool?
    #endif
    var specs: [WindowID: Spec] = [:]
    var cornerRadii: [WindowID: CGFloat] = [:]
    /// Global draw order (#367).
    private var activeOrder: BorderGeometry.Order = .below
    var eventSource: SkyLightWindowEvents?
    var triedEventSource = false
    var privateRuntimeStarted = false
    var skyLightActive = false
    /// QA lever forcing the AX-fallback path (#596): set from
    /// `KIWIDESK_NO_WS_TRACKING` at wiring — the settle-tail
    /// symptoms are AX-fallback-only and the WS stream is up on
    /// every developer Mac, so without a lever they are
    /// unobservable.
    var windowServerTrackingDisabled = false
    /// A front-order ring's read of its target's window level,
    /// live by default; a test core pins it (#1868).
    var windowLevel: (CGWindowID) -> Int? =
        AppKitBorderOverlay.windowLayer
    var reportedTrackingActive: Bool?
    var onLog: @MainActor (String) -> Void = CoreLog.write
    /// True while local animation drives this window (#594).
    var isAnimating: @MainActor (WindowID) -> Bool = { _ in false }

    /// Engine's commanded instant target while echo is pending (#881).
    var commandedFrame: @MainActor (WindowID) -> CGRect? = {
        _ in nil
    }
    /// WindowServer bounds query seam for testability.
    var readWindowBounds: @MainActor (WindowID) -> CGRect? = {
        SkyLight.windowBounds($0.raw)
    }
    /// WindowServer bounds reconcile tee for sticky marks (QA 2026-07-21).
    var onFrameReconciled: @MainActor (WindowID, CGRect) -> Void = { _, _ in }
    /// WindowServer z-order reorder tee (owner QA 2026-07-21): a
    /// re-click on an ALREADY-focused window raises it above its
    /// own mark yet fires no AX focus event, so the focus-driven
    /// re-sync never runs — this is what reaches the mark instead.
    var onWindowReordered: @MainActor (WindowID) -> Void = { _ in }
    /// Windows tracked for state mark z-order without active rings
    /// — every window wearing a mark (#414, #1799).
    var markTracked: Set<WindowID> = []

    /// Drives the dead-end rubber-band bounce (#436).
    let bumpAnimator = BorderBumpAnimator()
    /// Overlay pill for minimum size refusal cues (#933).
    let sizeLimitOverlay = SizeLimitOverlay()

    /// Test observation seam for resize refusal cues (#933).
    var onResizeRefusal: (ResizeRefusal) -> Void = { _ in }
    /// Test observation seam for Tile refusal cues (#1810).
    var onTileRefusal: (WindowID, AutoFloatReason) -> Void = { _, _ in }

    /// Observers for key window transitions (#933).
    var ownKeyWindowObservers: [NSObjectProtocol] = []

    public init() {}

    /// Enables private WindowServer tracking after application startup.
    func start() {
        privateRuntimeStarted = true
    }

    /// Retires all rings and disables private callbacks.
    func stop() {
        clear()
        privateRuntimeStarted = false
        skyLightActive = false
        reportedTrackingActive = nil
    }

    /// Windows currently wearing a ring.
    public var borderedWindows: Set<WindowID> {
        Set(overlays.keys)
    }

    /// Sets draw order (behind or in front of windows, #367).
    public func setDrawOrder(_ order: BorderStyle.DrawOrder) {
        let mapped: BorderGeometry.Order =
            order == .front ? .above : .below
        guard mapped != activeOrder else { return }
        for overlay in overlays.values { overlay.hide() }
        for overlay in dormant.values { overlay.hide() }
        overlays.removeAll()
        dormant.removeAll()
        activeOrder = mapped
    }

    /// Window corner radius from SkyLight or system fallback (#357).
    func cornerRadius(for id: WindowID) -> CGFloat {
        if let cached = cornerRadii[id] { return cached }
        let resolved =
            SkyLight.windowCornerRadius(id.raw)
            ?? GeometryUtils.systemWindowCornerRadius
        cornerRadii[id] = resolved
        return resolved
    }

    /// Retires all rings and resets tracking state.
    public func clear() {
        bumpAnimator.flushAll()
        for overlay in overlays.values { overlay.hide() }
        for overlay in dormant.values { overlay.hide() }
        for overlay in bumpTransients.values { overlay.hide() }
        overlays = [:]
        dormant = [:]
        bumpTransients = [:]
        specs = [:]
        cornerRadii = [:]
        markTracked = []
        _ = eventSource?.watch([])
    }

    /// Settles in-flight bounces when displays change.
    func displaysChanged() {
        bumpAnimator.flushAll()
    }

    /// Clears cached corner radius on transient teardown (#308).
    func forgetCornerRadius(_ id: WindowID) {
        cornerRadii[id] = nil
    }

    /// The window's ring, creating one if needed — a mutating
    /// getter only `sync` may call. The dead-end bounce routes
    /// around it via `makeOverlay` into a separate store, so a
    /// concurrent `sync` can never adopt or stomp its transient.
    func overlay(for window: WindowID) -> BorderOverlay {
        if let existing = overlays[window] { return existing }
        let overlay =
            dormant.removeValue(forKey: window)
            ?? makeOverlay(for: window)
        overlays[window] = overlay
        return overlay
    }

    /// Builds a ring overlay for `window` (#361, #367).
    func makeOverlay(for window: WindowID) -> BorderOverlay {
        BorderOverlay(
            window: window.raw,
            order: activeOrder,
            levelOf: windowLevel
        )
    }

    /// Display containing majority of frame for pixel scaling (#449).
    func screen(for frame: CGRect) -> NSScreen? {
        TilingEngine.screen(containing: frame) ?? NSScreen.main
    }
}
