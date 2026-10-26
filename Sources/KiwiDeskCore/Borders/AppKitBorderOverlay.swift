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

    /// Holds the ring's layers where the ring sits in its panel,
    /// which may be larger than the ring while it moves (#1937).
    private let container = CALayer()
    /// The panel's placement, shared with both marks (#1956, #2531).
    private let placement: PanelPlacement
    let shape = CAShapeLayer()
    /// Secondary shadow layer stacked under ring for edge bloom density
    /// (#533).
    let glowBoost = CAShapeLayer()
    /// The sheen ramp over the stroke (#1644), masked to it, so
    /// the bloom below keeps the plain stroke's shadow.
    let sheen = CAGradientLayer()
    let sheenMask = CAShapeLayer()
    /// Cut the bloom's interior out of the two shadow layers, so
    /// an above-order glow never paints over its window.
    let shapeGlowMask = CAShapeLayer()
    let boostGlowMask = CAShapeLayer()

    /// Stacks relative to the target window: `below` preserves
    /// popover occlusion (#320), `above` is `draw_order` front.
    let orderMode: BorderGeometry.Order
    /// The target's WindowServer layer, nil when unreadable. An
    /// above-order panel takes it, or a raised target's band
    /// would cover the ring.
    private let levelOf: (CGWindowID) -> Int?
    /// Moves the panel's window to a top-left origin without
    /// AppKit's fence (#1956); false sends it through AppKit.
    var movePanel: (CGWindowID, CGPoint) -> Bool {
        get { placement.movePanel }
        set { placement.movePanel = newValue }
    }
    /// Ordered in by AppKit and not ordered out since: the panel's
    /// physical state, beside `BorderOverlay.needsOrder`, which is
    /// the manager's policy — keep the two apart.
    private(set) var isOrderedIn = false
    #if DEBUG
        /// Test-only: orders AppKit performed. Production must not
        /// read it.
        private(set) var appKitOrders = 0
        /// Test-only: panel frames handed to AppKit.
        var frameSets: Int { placement.frameSets }
        /// Test-only: panel moves handed to SkyLight.
        var skyLightMoves: Int { placement.skyLightMoves }
    #endif

    init(
        order: BorderGeometry.Order = .below,
        levelOf: @escaping (CGWindowID) -> Int? =
            AppKitBorderOverlay.windowLayer,
        movePanel: @escaping (CGWindowID, CGPoint) -> Bool,
        pass: @escaping @MainActor () -> UInt64 =
            MainRunLoopPass.current
    ) {
        orderMode = order
        self.levelOf = levelOf
        placement = PanelPlacement(movePanel: movePanel, pass: pass)
    }

    /// The panel's Spaces/Exposé behavior, nil before the first
    /// render.
    var panelBehavior: NSWindow.CollectionBehavior? {
        panel?.collectionBehavior
    }

    #if DEBUG
        /// Test-only: AppKit's cached frame, which lags a SkyLight
        /// move; production reads the placement's frame (#1956).
        var panelFrame: CGRect? { panel?.frame }
    #endif
    /// The ring's place in its panel, AppKit coordinates.
    var ringFrameInPanel: CGRect { container.frame }

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
        let info = WindowListRead.copy(
            "windowLayerFallback",
            .optionIncludingWindow,
            relativeTo: window
        )
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
        screen: NSScreen?,
        room: CGRect?
    ) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let ring = GeometryUtils.flip(
            geometry.overlayFrame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        let frame = placement.place(panel, at: ring, room: room)
        container.frame = ring.offsetBy(dx: -frame.minX, dy: -frame.minY)
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
        // AppKit's order, every time: WindowServer applies no
        // SkyLight order to an AppKit panel (#1962).
        placement.order(panel) {
            panel.order(
                orderMode == .above ? .above : .below,
                relativeTo: Int(windowNumber)
            )
        }
        #if DEBUG
            appKitOrders += 1
        #endif
        isOrderedIn = true
    }

    /// Joins every Desktop while the ring's window is carried
    /// (#2149); `BorderOverlay` re-homes a ring that stops.
    func setSpansDesktops(_ on: Bool) {
        if on {
            panel?.collectionBehavior.insert(.canJoinAllSpaces)
        } else {
            panel?.collectionBehavior.remove(.canJoinAllSpaces)
        }
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

    /// Fades a dormant ring in over its content's layer: a
    /// window's own alpha takes no Core Animation (#1959).
    func reveal(reduceMotion: Bool) {
        guard let layer = panel?.contentView?.layer else {
            panel?.alphaValue = 1
            return
        }
        // The fade reaches the render server ahead of the window's
        // alpha, or one frame draws the ring whole.
        CATransaction.begin()
        layer.removeAnimation(forKey: "reveal")
        layer.add(
            BarMotion.opacityFade(
                from: 0,
                to: 1,
                begin: CACurrentMediaTime(),
                duration: Self.revealDuration,
                reduceMotion: reduceMotion
            ),
            forKey: "reveal"
        )
        CATransaction.commit()
        CATransaction.flush()
        panel?.alphaValue = 1
    }

    /// The reveal's length: a cue that the window has arrived
    /// (#1959).
    static let revealDuration: CFTimeInterval = 0.15

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
        // No `.canJoinAllSpaces`: the ring stays on its window's
        // Desktop unless `setSpansDesktops` says it is carried
        // (#2149, #1145); `.transient` hides it in Mission
        // Control, which a raw SkyLight window never does (#1917).
        panel.collectionBehavior = [
            .transient,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        let view = NSView()
        view.wantsLayer = true
        // Boost below the ring so the stacked bloom never paints
        // over the crisp stroke.
        view.layer?.addSublayer(container)
        container.addSublayer(glowBoost)
        container.addSublayer(shape)
        container.addSublayer(sheen)
        panel.contentView = view
        return panel
    }
}
