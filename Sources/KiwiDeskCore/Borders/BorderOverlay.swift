import AppKit

/// One focus-ring renderer. The SkyLight implementation returns
/// `false` after any private-API failure so the facade can retire it
/// and replay the latest state through the mandatory AppKit fallback.
@MainActor
protocol BorderOverlayBackend: AnyObject {
    /// Where this backend stacks its ring, which the facade needs to
    /// build the matching geometry: SkyLight draws `above` the target
    /// (visible hairline overlap), AppKit draws `below` it (masked
    /// overlap). The facade recomputes geometry for this mode on
    /// every render and after a fallback swap (#357).
    var orderMode: BorderGeometry.Order { get }
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) -> Bool
    func order(relativeTo windowNumber: CGWindowID) -> Bool
    func hide() -> Bool
}

/// Per-ring backend facade (#285 Tier 2). SkyLight is attempted only
/// after its drawing and event surfaces both initialized; a missing
/// symbol or failed operation permanently moves this ring to AppKit.
@MainActor
final class BorderOverlay {
    private var backend: any BorderOverlayBackend
    /// The raw inputs of the last render, kept so a fallback swap can
    /// rebuild geometry for the new backend's order mode — the
    /// `above` SkyLight geometry cannot be reused by the `below`
    /// AppKit panel (#357).
    private var lastFrame: CGRect?
    private var lastWidth: CGFloat = 0
    private var lastCornerStyle: BorderStyle.CornerStyle = .rounded
    private var lastColorHex = ""
    private weak var lastScreen: NSScreen?
    private var targetWindow: CGWindowID
    /// The target's real corner radius, resolved by `BorderManager`
    /// (which owns OS I/O) and passed in, so the facade stays a pure
    /// backend assembler and the radius path is injectable (#357).
    private var lastCornerRadius: CGFloat =
        GeometryUtils.systemWindowCornerRadius
    private var isHidden = false
    private let makeFallback: @MainActor () -> any BorderOverlayBackend
    private let onFallback: @MainActor (String) -> Void

    init(
        window: CGWindowID,
        order: BorderGeometry.Order,
        onFallback: @escaping @MainActor (String) -> Void
    ) {
        targetWindow = window
        self.onFallback = onFallback
        makeFallback = { AppKitBorderOverlay() }
        // `above`-order is the SkyLight fast path; `below`-order is
        // AppKit. The transport follows the requested draw order —
        // AppKit cannot express a visible above-window ring, and the
        // SkyLight sub-level path is what makes `above` non-flickering
        // occlusion-correct (#357/#367).
        let preferSkyLight = order == .above
        if preferSkyLight,
            let skyLight = SkyLightBorderOverlay(targetWindow: window)
        {
            backend = skyLight
        } else {
            backend = AppKitBorderOverlay()
            if preferSkyLight {
                onFallback("SLS renderer initialization failed")
            }
        }
    }

    /// Test seam for exercising facade behavior without creating a
    /// real AppKit or SkyLight window.
    init(
        window: CGWindowID,
        backend: any BorderOverlayBackend,
        fallback: (any BorderOverlayBackend)? = nil
    ) {
        targetWindow = window
        self.backend = backend
        makeFallback = {
            fallback ?? AppKitBorderOverlay()
        }
        onFallback = { _ in }
    }

    /// Renders the ring around `frame` (AX coords). Takes the raw
    /// inputs, not a finished `BorderGeometry`, because the geometry
    /// depends on the current backend's order mode — the facade owns
    /// that choice and rebuilds it here and on any fallback swap.
    func update(
        frame: CGRect,
        width: CGFloat,
        cornerStyle: BorderStyle.CornerStyle,
        cornerRadius: CGFloat,
        colorHex: String,
        screen: NSScreen?,
        restoreVisibility: Bool = false
    ) {
        lastFrame = frame
        lastWidth = width
        lastCornerStyle = cornerStyle
        lastCornerRadius = cornerRadius
        lastColorHex = colorHex
        lastScreen = screen
        let shouldRestore = restoreVisibility && isHidden
        guard
            backend.update(
                geometry: geometry(for: backend),
                colorHex: colorHex,
                screen: screen
            )
        else {
            fallBackToAppKit(reason: "SLS renderer update failed")
            if shouldRestore { order(relativeTo: targetWindow) }
            return
        }
        if shouldRestore {
            order(relativeTo: targetWindow)
        }
    }

    func order(relativeTo windowNumber: CGWindowID) {
        targetWindow = windowNumber
        isHidden = false
        guard backend.order(relativeTo: windowNumber) else {
            fallBackToAppKit(reason: "SLS renderer ordering failed")
            return
        }
    }

    /// Builds the ring geometry for a backend's order mode from the
    /// last rendered inputs.
    private func geometry(
        for backend: any BorderOverlayBackend
    ) -> BorderGeometry {
        BorderGeometry.compute(
            windowFrame: lastFrame ?? .zero,
            width: lastWidth,
            cornerStyle: lastCornerStyle,
            order: backend.orderMode,
            systemRadius: lastCornerRadius
        )
    }

    func hide() {
        isHidden = true
        guard backend.hide() else {
            fallBackToAppKit(
                reason: "SLS renderer hide failed",
                retireBackend: false
            )
            return
        }
    }

    func useAppKitFallback() {
        fallBackToAppKit(reason: "WindowServer event stream failed")
    }

    private func fallBackToAppKit(
        reason: String,
        retireBackend: Bool = true
    ) {
        guard !(backend is AppKitBorderOverlay) else { return }
        onFallback(reason)
        if retireBackend { _ = backend.hide() }
        let appKit = makeFallback()
        backend = appKit
        if lastFrame != nil {
            _ = appKit.update(
                geometry: geometry(for: appKit),
                colorHex: lastColorHex,
                screen: lastScreen
            )
            if isHidden {
                _ = appKit.hide()
            } else {
                _ = appKit.order(relativeTo: targetWindow)
            }
        }
    }
}

/// One window's focus-border ring (#278): a borderless,
/// non-activating, shadowless panel that ignores mouse events and
/// draws a single stroked rounded rect. The manager
/// (`BorderManager`) creates one per bordered window and feeds it
/// geometry; the overlay knows nothing about layouts or focus.
///
/// Non-interactive by design (`ignoresMouseEvents`) — unlike the
/// app bar, a border is never clicked. Sits at the normal window
/// level and is stacked directly behind its target window with
/// `order(.below, relativeTo:)` (see `order(relativeTo:)`). The stroke's
/// inner overlap sits under the target while its outward reach stays
/// visible; child panels and other windows above the target therefore
/// cover the ring naturally.
@MainActor
private final class AppKitBorderOverlay: BorderOverlayBackend {
    private var panel: NSPanel?
    private let shape = CAShapeLayer()

    /// The AppKit panel stacks below its target (it cannot express a
    /// SkyLight sub-level, so `above` here would paint over child
    /// popovers — the #320 regression). Below keeps that occlusion
    /// correct at the cost of the rounded corner seam, which only
    /// the SkyLight `above` path fixes.
    let orderMode: BorderGeometry.Order = .below

    /// Positions the ring around `geometry.overlayFrame` (AX
    /// coords) and strokes it in `colorHex`. Used both for a
    /// steady-state sync and per animation tick — implicit Core
    /// Animation is disabled so the ring snaps to each commanded
    /// frame instead of easing a step behind the window. Stacking
    /// is left to `order(relativeTo:)`, called only on sync (not per
    /// tick) so the ring isn't re-ordered every frame.
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) -> Bool {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrame(
            GeometryUtils.flip(
                geometry.overlayFrame,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: false
        )
        let bounds = CGRect(
            origin: .zero,
            size: geometry.overlayFrame.size
        )
        shape.frame = bounds
        // Stroke is centered on its path, so inset the path by
        // half the line width to keep the whole stroke inside the
        // overlay bounds.
        let rect = bounds.insetBy(
            dx: geometry.lineWidth / 2,
            dy: geometry.lineWidth / 2
        )
        shape.path = CGPath(
            roundedRect: rect,
            cornerWidth: geometry.cornerRadius,
            cornerHeight: geometry.cornerRadius,
            transform: nil
        )
        shape.lineWidth = geometry.lineWidth
        shape.strokeColor = NSColor(kiwiHex: colorHex).cgColor
        shape.fillColor = NSColor.clear.cgColor
        shape.contentsScale = screen?.backingScaleFactor ?? 2
        CATransaction.commit()
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        return true
    }

    /// Stacks the ring directly behind its target window in the
    /// global window order (`windowNumber` is the target's
    /// `CGWindowID`). Anything layered over the target — an
    /// ignored panel, a higher-level utility window — therefore
    /// stays in front of the ring. Called on sync, not per tick.
    /// A no-op until the panel exists (first `update` creates it).
    func order(relativeTo windowNumber: CGWindowID) -> Bool {
        panel?.order(.below, relativeTo: Int(windowNumber))
        return true
    }

    func hide() -> Bool {
        panel?.orderOut(nil)
        return true
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // Normal window level (not floating): the ring is stacked
        // relative to its target by `order(relativeTo:)`, so it must
        // share the target's band to sit *below* windows layered
        // over it — a floating level would force it above them.
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // Stay on the window's own Space; a fullscreen window
        // gets no border (auxiliary only). Not cycled by the app
        // switcher.
        panel.collectionBehavior = [
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        let view = NSView()
        view.wantsLayer = true
        view.layer?.addSublayer(shape)
        panel.contentView = view
        return panel
    }
}
