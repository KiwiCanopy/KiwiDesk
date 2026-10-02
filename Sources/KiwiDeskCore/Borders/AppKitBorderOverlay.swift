import AppKit

/// The focus ring's NSPanel (#278, #320). The one ring backend
/// since #1917: macOS 27 composites a raw SkyLight window over
/// the Mission Control overview, and `.transient` hides this one.
@MainActor
final class AppKitBorderOverlay: BorderOverlayBackend {
    private var panel: NSPanel?

    /// AppKit keeps a visible panel alive after its owner is gone,
    /// so a dropped overlay would leave it on screen (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    private let shape = CAShapeLayer()
    /// Secondary shadow layer stacked under ring for edge bloom density
    /// (#533).
    private let glowBoost = CAShapeLayer()
    /// The sheen ramp over the stroke (#1644), masked to it, so
    /// the bloom below keeps the plain stroke's shadow.
    private let sheen = CAGradientLayer()
    private let sheenMask = CAShapeLayer()

    /// Stacks relative to the target window: `below` preserves
    /// popover occlusion (#320), `above` is `draw_order` front.
    let orderMode: BorderGeometry.Order

    init(order: BorderGeometry.Order = .below) {
        orderMode = order
    }

    /// The panel's Spaces/Exposé behavior, nil before the first
    /// render.
    var panelBehavior: NSWindow.CollectionBehavior? {
        panel?.collectionBehavior
    }

    /// Updates ring geometry, stroke color, and glow bloom
    /// (#358). Implicit Core Animation is disabled so the ring
    /// snaps to each commanded frame instead of easing a step
    /// behind the window; stacking is `order(relativeTo:)`'s job,
    /// called on sync only, never per tick.
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) {
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
        let inset = geometry.glowMargin + geometry.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        shape.path = CGPath(
            roundedRect: rect,
            cornerWidth: geometry.cornerRadius,
            cornerHeight: geometry.cornerRadius,
            transform: nil
        )
        shape.lineWidth = geometry.lineWidth
        // Under the sheen the ramp is the stroke: a second one
        // beneath would stack a translucent colour's alpha.
        shape.strokeColor =
            geometry.sheen != 0
            ? NSColor.clear.cgColor
            : NSColor(kiwiHex: colorHex).cgColor
        shape.fillColor = NSColor.clear.cgColor
        shape.contentsScale = screen?.backingScaleFactor ?? 2
        applyGlow(geometry: geometry, rect: rect, colorHex: colorHex)
        applySheen(geometry: geometry, rect: rect, colorHex: colorHex)
        CATransaction.commit()
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /// Renders outer glow halo from filled silhouette (#358, #533).
    private func applyGlow(
        geometry: BorderGeometry,
        rect: CGRect,
        colorHex: String
    ) {
        guard geometry.glowMargin > 0 else {
            shape.shadowOpacity = 0
            shape.shadowColor = nil
            shape.shadowPath = nil
            glowBoost.shadowOpacity = 0
            glowBoost.shadowColor = nil
            glowBoost.shadowPath = nil
            return
        }
        let half = geometry.lineWidth / 2
        let radius = geometry.cornerRadius
        let outerRadius = radius <= 0 ? 0 : radius + half
        let silhouette = CGPath(
            roundedRect: rect.insetBy(dx: -half, dy: -half),
            cornerWidth: outerRadius,
            cornerHeight: outerRadius,
            transform: nil
        )
        let glow = NSColor.kiwiGlow(hex: colorHex)
        shape.shadowColor = glow
        shape.shadowRadius = geometry.glowMargin
        shape.shadowOpacity = 1
        shape.shadowOffset = .zero
        shape.shadowPath = silhouette
        glowBoost.frame = shape.frame
        glowBoost.shadowColor = glow
        glowBoost.shadowRadius = geometry.glowMargin / 2
        glowBoost.shadowOpacity = 1
        glowBoost.shadowOffset = .zero
        glowBoost.shadowPath = silhouette
    }

    /// Paints the sheen ramp over the stroke's own extent (#1644).
    private func applySheen(
        geometry: BorderGeometry,
        rect: CGRect,
        colorHex: String
    ) {
        sheen.isHidden = geometry.sheen == 0
        guard geometry.sheen != 0 else { return }
        let half = geometry.lineWidth / 2
        sheen.frame = rect.insetBy(dx: -half, dy: -half)
        sheen.contentsScale = shape.contentsScale
        sheenMask.frame = sheen.bounds
        sheenMask.path = CGPath(
            roundedRect: rect.offsetBy(
                dx: half - rect.minX,
                dy: half - rect.minY
            ),
            cornerWidth: geometry.cornerRadius,
            cornerHeight: geometry.cornerRadius,
            transform: nil
        )
        sheenMask.lineWidth = geometry.lineWidth
        sheenMask.strokeColor = NSColor.black.cgColor
        sheenMask.fillColor = nil
        sheenMask.contentsScale = shape.contentsScale
        sheen.mask = sheenMask
        BorderSheen.paint(
            sheen,
            hex: colorHex,
            strength: geometry.sheen
        )
    }

    /// Stacks the ring directly behind or above the target.
    func order(relativeTo windowNumber: CGWindowID) {
        panel?.order(
            orderMode == .above ? .above : .below,
            relativeTo: Int(windowNumber)
        )
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        // BorderOverlayPanel avoids frame clamping on top edge (#436).
        let panel = BorderOverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // Normal level, not floating: the ring is stacked
        // relative to its target and must share the target's band
        // to sit below windows layered over it.
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // `.canJoinAllSpaces`: the ring follows a carried sticky
        // window across Desktops (#1145), the bars' recipe;
        // `.transient` hides it in Mission Control (#1917).
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .transient,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        let view = NSView()
        view.wantsLayer = true
        // Boost below the ring so the stacked bloom never paints
        // over the crisp stroke.
        view.layer?.addSublayer(glowBoost)
        view.layer?.addSublayer(shape)
        view.layer?.addSublayer(sheen)
        panel.contentView = view
        return panel
    }
}
