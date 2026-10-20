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
        /// Whether the ring joins every Desktop: its window is
        /// carried (#2149, #1145).
        public let spansDesktops: Bool
        /// The native Space its screen shows, nil where unknown —
        /// a ring revived on another is re-homed (#2149).
        public let desktop: UInt64?

        public init(
            window: WindowID,
            frame: CGRect,
            colorHex: String,
            width: CGFloat,
            cornerStyle: BorderStyle.CornerStyle,
            glowBlur: CGFloat = 0,
            sheen: CGFloat = 0,
            spansDesktops: Bool = false,
            desktop: UInt64? = nil
        ) {
            self.window = window
            self.frame = frame
            self.colorHex = colorHex
            self.width = width
            self.cornerStyle = cornerStyle
            self.glowBlur = glowBlur
            self.sheen = sheen
            self.spansDesktops = spansDesktops
            self.desktop = desktop
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
    var privateRuntimeStarted = false
    /// The WindowServer stream the ring hears through (#2275).
    let watch: WindowServerWatch
    /// A front-order ring's read of its target's window level,
    /// live by default; a test core pins it (#1868).
    var windowLevel: (CGWindowID) -> Int? =
        AppKitBorderOverlay.windowLayer
    /// A ring's panel move, live by default and its one live
    /// default; a test core pins it to the AppKit fallback (#1956).
    var movePanel: (CGWindowID, CGPoint) -> Bool =
        SkyLight.moveWindow
    /// A window's corner radius read, live by default; a test core
    /// pins it (#1894).
    var readCornerRadius: (CGWindowID) -> CGFloat? =
        SkyLight.windowCornerRadius
    #if DEBUG
        /// Test-only: builds ring backends in the manager's order.
        /// Production must not set it; every test core sets it to
        /// the inert backend, so a real panel needs its own manager.
        var backendFactory:
            ((BorderGeometry.Order) -> any BorderOverlayBackend)?
    #endif
    var onLog: @MainActor (String) -> Void = CoreLog.write
    /// Speaks a refusal pill for VoiceOver (#2480); a live default
    /// both `makeTestCore` twins pin inert.
    var announceRefusal: @MainActor (String) -> Void =
        KiwiCore.postAnnouncement
    /// True while local animation drives this window (#594).
    var isAnimating: @MainActor (WindowID) -> Bool = { _ in false }
    #if DEBUG
        /// Test-only: the screen frame `room(for:screen:)` uses in
        /// place of the host's. Production must not read it.
        var roomScreenOverride: CGRect?
    #endif

    /// Engine's commanded instant target while echo is pending (#881).
    var commandedFrame: @MainActor (WindowID) -> CGRect? = {
        _ in nil
    }
    /// The ring a Space switch keeps dormant until its window
    /// arrives (#1959, `BorderManager+Arrival`).
    var arrival: ArrivalHold?
    /// The render-server clock the hold is timed on, the slide's.
    var arrivalClock: @MainActor () -> CFTimeInterval = {
        CACurrentMediaTime()
    }
    /// Runs the hold's next check after a delay; a test steps it.
    var scheduleArrivalCheck:
        @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void =
            { delay, check in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    MainActor.assumeIsolated { check() }
                }
            }
    /// The Reduce Motion read the reveal names (borders.md).
    var reduceMotion: @MainActor () -> Bool = { BarMotion.isReduced }

    /// Drives the dead-end rubber-band bounce (#436).
    let bumpAnimator = BorderBumpAnimator()
    /// Overlay pill for minimum size refusal cues (#933).
    let sizeLimitOverlay = SizeLimitOverlay()
    /// A lens hold's reminder pill (#2103): its own overlay, so a
    /// refusal flashed on the held window never replaces it.
    let holdPillOverlay = SizeLimitOverlay()

    /// Test observation seam for resize refusal cues (#933).
    var onResizeRefusal: (ResizeRefusal) -> Void = { _ in }
    /// Test observation seam for Tile refusal cues (#1810).
    var onTileRefusal: (WindowID, AutoFloatReason) -> Void = { _, _ in }

    /// Observers for key window transitions (#933).
    var ownKeyWindowObservers: [NSObjectProtocol] = []

    /// `watch` is the core's one stream, built by `KiwiCore`; a
    /// test's standalone default is never started, so it never
    /// attaches.
    public init(watch: WindowServerWatch = WindowServerWatch()) {
        self.watch = watch
        connectRing()
    }

    /// Enables private WindowServer tracking after application startup.
    func start() {
        privateRuntimeStarted = true
    }

    /// Retires all rings and disables private callbacks.
    func stop() {
        clear()
        privateRuntimeStarted = false
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
        watch.request([], for: .ring)
    }

    /// The panel of `id`'s ring where it is ordered in BEHIND its
    /// window — what a KiwiVision plate stacks under, or it covers
    /// the ring (#2103). Nil for a front ring, which clears the
    /// plate by sitting above its window.
    func ringPanel(of id: WindowID) -> CGWindowID? {
        guard activeOrder == .below else { return nil }
        return overlays[id]?.backend.orderedPanelNumber
    }

    /// Window corner radius from SkyLight or system fallback (#357).
    func cornerRadius(for id: WindowID) -> CGFloat {
        if let cached = cornerRadii[id] { return cached }
        let resolved =
            readCornerRadius(id.raw)
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
        arrival = nil
        watch.request([], for: .ring)
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
        #if DEBUG
            if let backendFactory {
                return BorderOverlay(
                    window: window.raw,
                    backend: backendFactory(activeOrder)
                )
            }
        #endif
        return BorderOverlay(
            window: window.raw,
            order: activeOrder,
            levelOf: windowLevel,
            movePanel: movePanel
        )
    }

    /// Display containing majority of frame for pixel scaling (#449).
    func screen(for frame: CGRect) -> NSScreen? {
        TilingEngine.screen(containing: frame) ?? ScreenList.main
    }
}
