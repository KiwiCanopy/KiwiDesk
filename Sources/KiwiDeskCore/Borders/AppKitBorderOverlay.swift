import AppKit

/// AppKit NSPanel fallback backend for window focus border rings (#278, #320).
@MainActor
final class AppKitBorderOverlay: BorderOverlayBackend {
    private var panel: NSPanel?
    private let shape = CAShapeLayer()
    /// Secondary shadow layer stacked under ring for edge bloom density
    /// (#533).
    private let glowBoost = CAShapeLayer()

    /// Stacks below target window to preserve popover occlusion (#320).
    let orderMode: BorderGeometry.Order = .below

    /// AppKit backend supports glow rendering (#533).
    let rendersGlow = true

    /// Updates ring geometry, stroke color, and glow bloom
    /// (#358). Implicit Core Animation is disabled so the ring
    /// snaps to each commanded frame instead of easing a step
    /// behind the window; stacking is `order(relativeTo:)`'s job,
    /// called on sync only, never per tick.
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
        let inset = geometry.glowMargin + geometry.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
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
        applyGlow(geometry: geometry, rect: rect, colorHex: colorHex)
        CATransaction.commit()
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        return true
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

    /// Stacks ring directly behind target window in WindowServer hierarchy.
    func order(relativeTo windowNumber: CGWindowID) -> Bool {
        panel?.order(.below, relativeTo: Int(windowNumber))
        return true
    }

    func hide() -> Bool {
        panel?.orderOut(nil)
        return true
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
        panel.collectionBehavior = [
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
        panel.contentView = view
        return panel
    }
}
