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

        public init(
            window: WindowID,
            frame: CGRect,
            colorHex: String,
            width: CGFloat,
            cornerStyle: BorderStyle.CornerStyle,
            glowBlur: CGFloat = 0
        ) {
            self.window = window
            self.frame = frame
            self.colorHex = colorHex
            self.width = width
            self.cornerStyle = cornerStyle
            self.glowBlur = glowBlur
        }
    }

    var overlays: [WindowID: BorderOverlay] = [:]
    /// Transient rings spawned for dead-end bounces when borders are disabled.
    var bumpTransients: [WindowID: BorderOverlay] = [:]
    var specs: [WindowID: Spec] = [:]
    var cornerRadii: [WindowID: CGFloat] = [:]
    /// Global draw order (#367).
    private var activeOrder: BorderGeometry.Order = .below
    var eventSource: SkyLightWindowEvents?
    var triedEventSource = false
    var privateRuntimeStarted = false
    var skyLightActive = false
    /// QA lever to disable WindowServer tracking path (#596).
    var windowServerTrackingDisabled = false
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
    /// WindowServer z-order reorder tee (owner QA 2026-07-21).
    var onWindowReordered: @MainActor (WindowID) -> Void = { _ in }
    /// Windows tracked for sticky mark z-order without active rings.
    var stickyTracked: Set<WindowID> = []

    /// Drives the dead-end rubber-band bounce (#436).
    let bumpAnimator = BorderBumpAnimator()
    /// Overlay pill for minimum size refusal cues (#933).
    let sizeLimitOverlay = SizeLimitOverlay()

    /// Test observation seam for resize refusal cues (#933).
    var onResizeRefusal: (ResizeRefusal) -> Void = { _ in }

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
        overlays.removeAll()
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
        for overlay in bumpTransients.values { overlay.hide() }
        overlays = [:]
        bumpTransients = [:]
        specs = [:]
        cornerRadii = [:]
        stickyTracked = []
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

    /// Returns existing or newly created overlay for steady-state sync.
    func overlay(for window: WindowID) -> BorderOverlay {
        if let existing = overlays[window] { return existing }
        let overlay = makeOverlay(for: window)
        overlays[window] = overlay
        return overlay
    }

    /// Builds a ring overlay for `window` (#361, #367).
    func makeOverlay(for window: WindowID) -> BorderOverlay {
        BorderOverlay(
            window: window.raw,
            order: activeOrder,
            onFallback: { [weak self] reason in
                self?.onLog(
                    "border \(window.raw): \(reason); "
                        + "using AppKit rendering"
                )
            }
        )
    }

    /// Display containing majority of frame for pixel scaling (#449).
    func screen(for frame: CGRect) -> NSScreen? {
        TilingEngine.screen(containing: frame) ?? NSScreen.main
    }
}
