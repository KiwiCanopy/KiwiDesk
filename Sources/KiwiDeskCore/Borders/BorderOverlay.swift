import AppKit

/// Focus-ring backend protocol (#357, #533).
@MainActor
protocol BorderOverlayBackend: AnyObject {
    var orderMode: BorderGeometry.Order { get }
    /// True if backend supports glow rendering (AppKit only, #533).
    var rendersGlow: Bool { get }
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) -> Bool
    func order(relativeTo windowNumber: CGWindowID) -> Bool
    func hide() -> Bool
}

extension BorderOverlayBackend {
    var rendersGlow: Bool { true }
}

/// Per-ring backend facade managing SkyLight and AppKit fallback (#285, #357).
@MainActor
final class BorderOverlay {
    private var backend: any BorderOverlayBackend
    private var lastFrame: CGRect?
    private var lastWidth: CGFloat = 0
    private var lastCornerStyle: BorderStyle.CornerStyle = .rounded
    private var lastColorHex = ""
    /// Resolved glow blur (`0` = no glow, #358, #551).
    private var lastGlowBlur: CGFloat = 0
    private weak var lastScreen: NSScreen?
    private var targetWindow: CGWindowID
    private var lastCornerRadius: CGFloat =
        GeometryUtils.systemWindowCornerRadius
    private var isHidden = false
    /// Dead-end rubber-band offset (#436).
    private var bumpOffset = CGVector.zero
    private let makeFallback: @MainActor () -> any BorderOverlayBackend
    private let makePreferred:
        @MainActor (CGWindowID) -> (any BorderOverlayBackend)?
    private let onFallback: @MainActor (String) -> Void
    private var skyLightRetired = false

    init(
        window: CGWindowID,
        order: BorderGeometry.Order,
        onFallback: @escaping @MainActor (String) -> Void
    ) {
        targetWindow = window
        self.onFallback = onFallback
        makeFallback = { AppKitBorderOverlay() }
        makePreferred = {
            SkyLightBorderOverlay(targetWindow: $0, order: order)
        }
        if let skyLight = SkyLightBorderOverlay(
            targetWindow: window,
            order: order
        ) {
            backend = skyLight
        } else {
            backend = AppKitBorderOverlay()
            skyLightRetired = true
            onFallback("SLS renderer initialization failed")
        }
    }

    /// Test seam for mocking backends (#533).
    init(
        window: CGWindowID,
        backend: any BorderOverlayBackend,
        fallback: (any BorderOverlayBackend)? = nil,
        preferred: (
            @MainActor (CGWindowID) -> (any BorderOverlayBackend)?
        )? = nil
    ) {
        targetWindow = window
        self.backend = backend
        makeFallback = {
            fallback ?? AppKitBorderOverlay()
        }
        makePreferred = preferred ?? { _ in nil }
        skyLightRetired = preferred == nil
        onFallback = { _ in }
    }

    /// Dynamically swaps backend when glow is toggled (#533).
    @discardableResult
    private func ensureBackend(glow: Bool) -> Bool {
        if glow, !backend.rendersGlow {
            _ = backend.hide()
            backend = makeFallback()
            return true
        }
        if !glow, !skyLightRetired, backend.rendersGlow {
            guard
                let preferred = makePreferred(targetWindow)
            else {
                skyLightRetired = true
                return false
            }
            _ = backend.hide()
            backend = preferred
            return true
        }
        return false
    }

    var lastRenderedFrame: CGRect? { lastFrame }

    /// Last rendered color hex (tested for geometry-independent recolor,
    /// #596).
    var lastRenderedColorHex: String { lastColorHex }

    /// Renders focus ring geometry around `frame` in AX coordinates.
    func update(
        frame: CGRect,
        width: CGFloat,
        cornerStyle: BorderStyle.CornerStyle,
        cornerRadius: CGFloat,
        colorHex: String,
        screen: NSScreen?,
        glowBlur: CGFloat = 0,
        restoreVisibility: Bool = false
    ) {
        lastFrame = frame
        lastWidth = width
        lastCornerStyle = cornerStyle
        lastCornerRadius = cornerRadius
        lastColorHex = colorHex
        lastScreen = screen
        lastGlowBlur = glowBlur
        let swapped = ensureBackend(glow: glowBlur > 0)
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
        if swapped && !shouldRestore {
            if isHidden {
                hide()
            } else {
                order(relativeTo: targetWindow)
            }
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

    /// Renders rubber-band bump offset for dead-end cue (#436).
    func renderBump(offset: CGVector, colorHex: String? = nil) {
        guard lastFrame != nil else { return }
        bumpOffset = offset
        _ = backend.update(
            geometry: geometry(for: backend),
            colorHex: colorHex ?? lastColorHex,
            screen: lastScreen
        )
    }

    private func geometry(
        for backend: any BorderOverlayBackend
    ) -> BorderGeometry {
        BorderGeometry.compute(
            windowFrame: (lastFrame ?? .zero).offsetBy(
                dx: bumpOffset.dx,
                dy: bumpOffset.dy
            ),
            width: lastWidth,
            cornerStyle: lastCornerStyle,
            order: backend.orderMode,
            systemRadius: lastCornerRadius,
            glowBlur: lastGlowBlur
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
        skyLightRetired = true
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
