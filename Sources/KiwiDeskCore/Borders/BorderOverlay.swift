import AppKit

/// One focus-ring renderer. The SkyLight implementation returns
/// `false` after any private-API failure so the facade can retire it
/// and replay the latest state through the mandatory AppKit fallback.
@MainActor
protocol BorderOverlayBackend: AnyObject {
    /// Where this backend stacks its ring, which the facade needs
    /// to build the matching geometry: `above` draws a visible
    /// hairline overlap on the target, `below` masks the overlap
    /// behind it. SkyLight renders either order; the AppKit
    /// fallback is below-only. The facade recomputes geometry for
    /// this mode on every render and after a fallback swap (#357).
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
    /// Whether the last render asked for the glow bloom (#358). Kept
    /// alongside the other raw inputs so a fallback swap or a
    /// dead-end bump rebuilds geometry with the same glow state.
    private var lastGlow = false
    private weak var lastScreen: NSScreen?
    private var targetWindow: CGWindowID
    /// The target's real corner radius, resolved by `BorderManager`
    /// (which owns OS I/O) and passed in, so the facade stays a pure
    /// backend assembler and the radius path is injectable (#357).
    private var lastCornerRadius: CGFloat =
        GeometryUtils.systemWindowCornerRadius
    private var isHidden = false
    /// The dead-end rubber-band's live offset (#436), layered on top
    /// of `lastFrame` when geometry is built. Held separately from
    /// `lastFrame` so a steady-state `sync` mid-bump keeps the offset
    /// instead of snapping the ring back to the un-shifted frame.
    private var bumpOffset = CGVector.zero
    private let makeFallback: @MainActor () -> any BorderOverlayBackend
    private let onFallback: @MainActor (String) -> Void
    /// The order this ring was created with, kept so a glow-driven
    /// backend swap (#533) can rebuild the SkyLight backend once
    /// glow turns back off.
    private let preferredOrder: BorderGeometry.Order
    /// True after a real SkyLight failure — a glow-off swap must
    /// never resurrect a backend that already failed.
    private var skyLightRetired = false

    init(
        window: CGWindowID,
        order: BorderGeometry.Order,
        onFallback: @escaping @MainActor (String) -> Void
    ) {
        targetWindow = window
        self.onFallback = onFallback
        preferredOrder = order
        makeFallback = { AppKitBorderOverlay() }
        // Both orders prefer the SkyLight transport: its window is
        // space-pinned at creation, so Mission Control leaves the
        // ring behind instantly — an NSPanel cannot be pinned and
        // lingers until settle. `above` keeps the sub-level path
        // that makes it occlusion-correct (#357/#367); `below`
        // orders beneath the target with none of that churn.
        // AppKit remains the fallback whenever the private surface
        // is unavailable or an operation fails.
        if let skyLight = SkyLightBorderOverlay(
            targetWindow: window,
            order: order
        ) {
            backend = skyLight
        } else {
            backend = AppKitBorderOverlay()
            onFallback("SLS renderer initialization failed")
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
        preferredOrder = backend.orderMode
        makeFallback = {
            fallback ?? AppKitBorderOverlay()
        }
        onFallback = { _ in }
    }

    /// A glow ring always renders on the AppKit backend (#533):
    /// the WindowServer-backed SkyLight context drops any
    /// `setShadow` colour to default black-at-low-alpha (a grey
    /// smear), and every painted-falloff substitute banded or
    /// clipped on device — while the `CAShapeLayer` shadow
    /// renders the bloom correctly. Plain rings stay on SkyLight
    /// for its space pin (instant Mission Control hide). The
    /// swap is two-way on the glow toggle, except after a real
    /// SkyLight failure, which stays retired. Swapping before
    /// the backend's first window exists is free — the SkyLight
    /// surface is created lazily on its first update.
    @discardableResult
    private func ensureBackend(glow: Bool) -> Bool {
        if glow, backend is SkyLightBorderOverlay {
            _ = backend.hide()
            backend = makeFallback()
            return true
        }
        if !glow, !skyLightRetired,
            backend is AppKitBorderOverlay,
            let skyLight = SkyLightBorderOverlay(
                targetWindow: targetWindow,
                order: preferredOrder
            )
        {
            _ = backend.hide()
            backend = skyLight
            return true
        }
        return false
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
        glow: Bool = false,
        restoreVisibility: Bool = false
    ) {
        lastFrame = frame
        lastWidth = width
        lastCornerStyle = cornerStyle
        lastCornerRadius = cornerRadius
        lastColorHex = colorHex
        lastScreen = screen
        lastGlow = glow
        let swapped = ensureBackend(glow: glow)
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
            // The fresh backend's window has no stacking yet —
            // re-assert what the old one had, like the fallback
            // swap replay does.
            if isHidden {
                _ = backend.hide()
            } else {
                _ = backend.order(relativeTo: targetWindow)
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

    /// Rubber-bands the ring by `offset` from its last real frame for
    /// the dead-end cue (#436), optionally overriding the stroke with
    /// `colorHex` (a Reduce-Motion opacity dip). Pure overlay motion:
    /// it re-renders geometry with implicit animation disabled and
    /// never touches the window, so no AX write and nothing for the
    /// tiling engine's frame authority to fight. A no-op before the
    /// first real render (no `lastFrame` to shift).
    func renderBump(offset: CGVector, colorHex: String? = nil) {
        guard lastFrame != nil else { return }
        bumpOffset = offset
        _ = backend.update(
            geometry: geometry(for: backend),
            colorHex: colorHex ?? lastColorHex,
            screen: lastScreen
        )
    }

    /// Builds the ring geometry for a backend's order mode from the
    /// last rendered inputs, plus any live dead-end bump offset.
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
            glow: lastGlow
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
