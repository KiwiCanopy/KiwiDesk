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
    /// The panel's frame of record, in AppKit coordinates. AppKit's
    /// own `panel.frame` lags a SkyLight move until WindowServer's
    /// moved event lands, so no decision reads it (#1956).
    private var placedFrame: CGRect?
    /// The main run loop pass in which AppKit last set the frame or
    /// first ordered the panel in; AppKit sends both at that pass's
    /// commit, over a SkyLight move issued before it (#1956).
    private var appKitPass: UInt64?
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
    var movePanel: (CGWindowID, CGPoint) -> Bool
    /// The main run loop's pass count (`MainRunLoopPass`).
    private let pass: @MainActor () -> UInt64
    /// Ordered in by AppKit and not ordered out since: the panel's
    /// physical state, beside `BorderOverlay.needsOrder`, which is
    /// the manager's policy — keep the two apart.
    private(set) var isOrderedIn = false
    #if DEBUG
        /// Test-only: orders AppKit performed. Production must not
        /// read it.
        private(set) var appKitOrders = 0
        /// Test-only: panel frames handed to AppKit.
        private(set) var frameSets = 0
        /// Test-only: panel moves handed to SkyLight.
        private(set) var skyLightMoves = 0
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
        self.movePanel = movePanel
        self.pass = pass
    }

    /// The panel's Spaces/Exposé behavior, nil before the first
    /// render.
    var panelBehavior: NSWindow.CollectionBehavior? {
        panel?.collectionBehavior
    }

    #if DEBUG
        /// Test-only: AppKit's cached frame, which lags a SkyLight
        /// move; production reads `placedFrame` (#1956).
        var panelFrame: CGRect? { panel?.frame }
    #endif
    /// The ring's place in its panel, AppKit coordinates.
    var ringFrameInPanel: CGRect { container.frame }

    /// The panel's frame for a ring: `room` while it holds the
    /// whole ring, else the ring's own. A panel resize hands
    /// WindowServer a fenced transaction the main actor waits on,
    /// per frame of an animation (#1937).
    nonisolated static func panelFrame(
        for ring: CGRect,
        room: CGRect?
    ) -> CGRect {
        guard let room, room.contains(ring) else { return ring }
        return room
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
        let frame = place(panel, holding: ring, room: room)
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

    /// Puts the panel where it holds `ring` and returns its frame:
    /// a panel the ring's size moves through SkyLight, mid-animation
    /// too, once WindowServer has its window (a window number, kept
    /// through an order-out) and AppKit has not set its frame this
    /// pass (#1956); else AppKit, the room while it holds the ring
    /// (#1937).
    private func place(
        _ panel: NSPanel,
        holding ring: CGRect,
        room: CGRect?
    ) -> CGRect {
        if panel.windowNumber > 0, appKitPass != pass(),
            let placed = placedFrame,
            placed.size == ring.size,
            placed == ring || moveThroughSkyLight(panel, to: ring)
        {
            placedFrame = ring
            return ring
        }
        let frame = Self.panelFrame(for: ring, room: room)
        if frame != placedFrame {
            panel.setFrame(frame, display: false)
            placedFrame = frame
            appKitPass = pass()
            #if DEBUG
                frameSets += 1
            #endif
        }
        return frame
    }

    private func moveThroughSkyLight(
        _ panel: NSPanel,
        to frame: CGRect
    ) -> Bool {
        let topLeft = GeometryUtils.flip(
            frame,
            primaryHeight: GeometryUtils.primaryHeight
        ).origin
        guard movePanel(CGWindowID(panel.windowNumber), topLeft)
        else { return false }
        #if DEBUG
            skyLightMoves += 1
        #endif
        return true
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
        let createsWindow = panel.windowNumber <= 0
        panel.order(
            orderMode == .above ? .above : .below,
            relativeTo: Int(windowNumber)
        )
        #if DEBUG
            appKitOrders += 1
        #endif
        if createsWindow {
            appKitPass = pass()
        }
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
        view.layer?.addSublayer(container)
        container.addSublayer(glowBoost)
        container.addSublayer(shape)
        container.addSublayer(sheen)
        panel.contentView = view
        return panel
    }
}
