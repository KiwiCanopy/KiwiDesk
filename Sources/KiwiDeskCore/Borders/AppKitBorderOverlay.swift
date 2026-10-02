import AppKit

/// The focus ring's NSPanel (#278, #320).
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
    /// Cut the bloom's interior out of the two shadow layers, so
    /// an above-order glow never paints over its window.
    private let shapeGlowMask = CAShapeLayer()
    private let boostGlowMask = CAShapeLayer()

    /// Stacks relative to the target window: `below` preserves
    /// popover occlusion (#320), `above` is `draw_order` front.
    let orderMode: BorderGeometry.Order
    /// The target's WindowServer layer, nil when unreadable. An
    /// above-order panel takes it, or a raised target's band
    /// would cover the ring.
    private let levelOf: (CGWindowID) -> Int?
    /// Re-stacks an ordered-in panel without AppKit's per-order
    /// rights lookup (#1925); false sends it through AppKit.
    var restack: (CGWindowID, Bool, CGWindowID) -> Bool =
        SkyLight.orderWindow
    /// Ordered in by AppKit and not ordered out since.
    private(set) var isOrderedIn = false

    init(
        order: BorderGeometry.Order = .below,
        levelOf: @escaping (CGWindowID) -> Int? =
            AppKitBorderOverlay.windowLayer
    ) {
        orderMode = order
        self.levelOf = levelOf
    }

    /// The panel's Spaces/Exposé behavior, nil before the first
    /// render.
    var panelBehavior: NSWindow.CollectionBehavior? {
        panel?.collectionBehavior
    }

    /// The panel's window number, nil before the first render.
    var panelNumber: Int? { panel?.windowNumber }

    /// The panel's alpha, nil before the first render.
    var panelAlpha: CGFloat? { panel?.alphaValue }

    /// The panel's level, nil before the first render.
    var panelLevel: NSWindow.Level? { panel?.level }

    /// The cut-out each glow shadow layer is masked with, nil for
    /// a layer drawing unmasked.
    var glowMaskPaths: [CGPath?] {
        [shape, glowBoost].map {
            ($0.mask as? CAShapeLayer)?.path
        }
    }

    /// Public CGWindowList read of `window`'s layer.
    nonisolated static func windowLayer(
        _ window: CGWindowID
    ) -> Int? {
        let info =
            CGWindowListCopyWindowInfo(
                .optionIncludingWindow,
                window
            ) as? [[String: Any]]
        return info?.first?[kCGWindowLayer as String] as? Int
    }

    /// Updates ring geometry, stroke color, and glow bloom
    /// (#358). Implicit Core Animation is disabled so the ring
    /// snaps to each commanded frame instead of easing a step
    /// behind the window; stacking — and ordering in — is
    /// `order(relativeTo:)`'s job, called on sync only, never per
    /// tick, so a hidden ring stays hidden through a re-render.
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
            shape.mask = nil
            glowBoost.mask = nil
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
        let inner = rect.insetBy(dx: half, dy: half)
        let innerRadius = max(0, radius - half)
        let cutout = CGMutablePath()
        cutout.addRect(shape.bounds)
        if inner.width > 0, inner.height > 0 {
            cutout.addRoundedRect(
                in: inner,
                cornerWidth: min(innerRadius, inner.width / 2),
                cornerHeight: min(innerRadius, inner.height / 2)
            )
        }
        for (layer, mask) in [
            (shape, shapeGlowMask), (glowBoost, boostGlowMask),
        ] {
            mask.frame = layer.bounds
            mask.path = cutout
            mask.fillRule = .evenOdd
            layer.mask = mask
        }
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

    /// Orders the ring in directly behind or above the target.
    func order(relativeTo windowNumber: CGWindowID) {
        guard let panel else { return }
        // An unread level keeps the last one rather than dropping
        // a raised target's ring into the normal band.
        if orderMode == .above, let raw = levelOf(windowNumber),
            panel.level.rawValue != raw
        {
            panel.level = NSWindow.Level(rawValue: raw)
        }
        if isOrderedIn,
            restack(
                CGWindowID(panel.windowNumber),
                orderMode == .above,
                windowNumber
            )
        {
            return
        }
        panel.order(
            orderMode == .above ? .above : .below,
            relativeTo: Int(windowNumber)
        )
        isOrderedIn = true
    }

    func hide() {
        panel?.orderOut(nil)
        isOrderedIn = false
    }

    /// Alpha, not `orderOut`: ordering out asks WindowServer
    /// whether the panel is shown, a round trip that stalls the
    /// main actor while WindowServer is GPU-bound (#1925).
    func setDormant(_ dormant: Bool) {
        panel?.alphaValue = dormant ? 0 : 1
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
        // `.transient` hides it in Mission Control, which on
        // macOS 27 a raw SkyLight window never does (#1917).
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
