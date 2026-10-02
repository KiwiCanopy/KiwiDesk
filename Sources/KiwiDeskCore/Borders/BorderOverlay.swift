import AppKit

/// Focus-ring backend: the production `AppKitBorderOverlay`, or
/// a test double exercising `BorderOverlay`'s replay without a
/// window.
@MainActor
protocol BorderOverlayBackend: AnyObject {
    var orderMode: BorderGeometry.Order { get }
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    )
    func order(relativeTo windowNumber: CGWindowID)
    func hide()
    /// Fades the ring out (or back) without ordering it out, so a
    /// retired ring costs no WindowServer round trip (#1925).
    func setDormant(_ dormant: Bool)
}

extension BorderOverlayBackend {
    func setDormant(_ dormant: Bool) {}
}

/// One window's focus ring (#285, #357): keeps the last render's
/// inputs and rebuilds geometry for the backend's order mode.
@MainActor
final class BorderOverlay {
    let backend: any BorderOverlayBackend
    private var lastFrame: CGRect?
    private var lastWidth: CGFloat = 0
    private var lastCornerStyle: BorderStyle.CornerStyle = .rounded
    private var lastColorHex = ""
    /// Resolved glow blur (`0` = no glow, #358, #551).
    private var lastGlowBlur: CGFloat = 0
    private var lastSheen: CGFloat = 0
    private weak var lastScreen: NSScreen?
    private var targetWindow: CGWindowID
    private var lastCornerRadius: CGFloat =
        GeometryUtils.systemWindowCornerRadius
    private var isHidden = false
    /// Retired by `sync` but kept for its window's return (#1925).
    private(set) var isDormant = false
    private var hasOrdered = false

    /// Whether a steady `sync` must order the ring in: AppKit
    /// pays a WindowServer round trip per order against another
    /// app's window, so a shown ring is left to the reorder
    /// events and the settle passes (#1925).
    var needsOrder: Bool { !hasOrdered || isHidden || isDormant }
    /// Dead-end rubber-band offset (#436).
    private var bumpOffset = CGVector.zero

    /// Builds the ring's AppKit panel in `order` (#1917).
    init(
        window: CGWindowID,
        order: BorderGeometry.Order,
        levelOf: @escaping (CGWindowID) -> Int? =
            AppKitBorderOverlay.windowLayer
    ) {
        targetWindow = window
        backend = AppKitBorderOverlay(order: order, levelOf: levelOf)
    }

    /// Test seam for mocking backends (#533).
    init(window: CGWindowID, backend: any BorderOverlayBackend) {
        targetWindow = window
        self.backend = backend
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
        sheen: CGFloat = 0,
        restoreVisibility: Bool = false
    ) {
        lastFrame = frame
        lastWidth = width
        lastCornerStyle = cornerStyle
        lastCornerRadius = cornerRadius
        lastColorHex = colorHex
        lastScreen = screen
        lastGlowBlur = glowBlur
        lastSheen = sheen
        let shouldRestore = restoreVisibility && isHidden
        backend.update(
            geometry: geometry(),
            colorHex: colorHex,
            screen: screen
        )
        if shouldRestore {
            order(relativeTo: targetWindow)
        }
    }

    func order(relativeTo windowNumber: CGWindowID) {
        targetWindow = windowNumber
        isHidden = false
        hasOrdered = true
        backend.order(relativeTo: windowNumber)
        if isDormant {
            isDormant = false
            backend.setDormant(false)
        }
    }

    /// Parks the ring invisibly for its window's return (#1925);
    /// the next `order(relativeTo:)` shows it again. Drops the
    /// held frame, or an animated return flashes the ring where
    /// it rested before its window slides in.
    func retire() {
        isDormant = true
        lastFrame = nil
        backend.setDormant(true)
    }

    /// Renders the rubber-band bump offset for the dead-end cue
    /// (#436). Pure overlay motion: it never touches the window —
    /// no AX write, nothing for the frame authority to fight.
    func renderBump(offset: CGVector, colorHex: String? = nil) {
        guard lastFrame != nil else { return }
        bumpOffset = offset
        backend.update(
            geometry: geometry(),
            colorHex: colorHex ?? lastColorHex,
            screen: lastScreen
        )
    }

    private func geometry() -> BorderGeometry {
        BorderGeometry.compute(
            windowFrame: (lastFrame ?? .zero).offsetBy(
                dx: bumpOffset.dx,
                dy: bumpOffset.dy
            ),
            width: lastWidth,
            cornerStyle: lastCornerStyle,
            order: backend.orderMode,
            systemRadius: lastCornerRadius,
            glowBlur: lastGlowBlur,
            sheen: lastSheen
        )
    }

    func hide() {
        isHidden = true
        backend.hide()
    }
}
