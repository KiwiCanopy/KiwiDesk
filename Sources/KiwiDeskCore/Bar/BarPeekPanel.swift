import AppKit

/// The peek's one panel (#1946): non-activating, above the bars,
/// deaf to the mouse and hidden from accessibility — read-only,
/// so it never takes a click or a hover, and VoiceOver keeps the
/// item's label and its menu. Its ground is the shelf's plate:
/// glass through `GlassTint.apply`, or the solid Fill.
@MainActor
final class BarPeekPanel {
    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    private(set) var panel: NSPanel?
    let body = BarPeekBody()
    private let root = NSView()
    private let solid = NSView()
    private let tint = GlassBackdrop()
    private var glass: NSView?
    /// The fade-out in flight; its landing orders the panel out
    /// unless a show cleared it meanwhile.
    private var leaving: UUID?
    /// What the panel shows; nil while it is closed.
    private(set) var drawn: BarPeekContent?

    var isShown: Bool { panel?.isVisible == true && drawn != nil }

    /// Shows `content` at the item framed `anchor` on a bar of
    /// `edge` whose panel is `strip`, opening away from the edge
    /// inside the screen's usable area `visible`, all in AppKit
    /// screen coordinates. A swap writes in place; `fades` fades a
    /// first show in.
    func show(
        _ content: BarPeekContent,
        shelf stored: KiwiShelf,
        edge: AppBarEdge,
        anchor: CGRect,
        strip: CGRect,
        visible: CGRect,
        fades: Bool
    ) {
        // The one place the stored shelf becomes the drawn one
        // (#1374): glass stands down while transparency is reduced.
        let shelf = LiquidGlassGate.rendered(stored)
        let size = Self.fittedSize(
            of: body,
            content,
            shelf: shelf,
            edge: edge,
            strip: strip,
            visible: visible
        )
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let origin = Self.origin(
            size: size,
            edge: edge,
            anchor: anchor,
            strip: strip,
            visible: visible
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
        paint(shelf, edge: edge, size: size)
        panel.invalidateShadow()
        leaving = nil
        drawn = content
        if !panel.isVisible {
            panel.alphaValue = fades ? 0 : 1
            panel.orderFrontRegardless()
        }
        BarMotion.fadePeek(panel, to: 1, animated: fades)
    }

    /// Closes the peek, fading where `animated`.
    func hide(animated: Bool) {
        drawn = nil
        guard let panel, panel.isVisible else { return }
        let token = UUID()
        leaving = token
        BarMotion.fadePeek(panel, to: 0, animated: animated) {
            [weak self] in
            guard let self, self.leaving == token else { return }
            self.leaving = nil
            self.panel?.orderOut(nil)
        }
    }

    /// The panel's size, its height bounded by the usable room
    /// on the far side of the strip, so a tall peek never covers
    /// its bar or item. The body fits itself to that room first
    /// (`BarPeekBody+More`); only what still passes it is clipped,
    /// and no title is capped on its own (#1946).
    nonisolated static func capped(
        _ size: CGSize,
        edge: AppBarEdge,
        strip: CGRect,
        visible: CGRect
    ) -> CGSize {
        CGSize(
            width: size.width,
            height: min(
                size.height,
                room(edge: edge, strip: strip, visible: visible)
            )
        )
    }

    /// The usable height on the far side of the strip.
    nonisolated static func room(
        edge: AppBarEdge,
        strip: CGRect,
        visible: CGRect
    ) -> CGFloat {
        typealias M = BarPeekBody.Metrics
        let room: CGFloat
        switch edge {
        case .top:
            room = strip.minY - M.stripGap - visible.minY - M.screenMargin
        case .bottom:
            room = visible.maxY - M.screenMargin - strip.maxY - M.stripGap
        case .left, .right:
            room = visible.height - 2 * M.screenMargin
        }
        return max(room, 0)
    }

    /// `content` laid out in `body` within the room on the far
    /// side of the strip, the panel's size — the one measure the
    /// show and the menu's anchor (`BarPeek.menuTopLeft`) both take.
    static func fittedSize(
        of body: BarPeekBody,
        _ content: BarPeekContent,
        shelf: KiwiShelf,
        edge: AppBarEdge,
        strip: CGRect,
        visible: CGRect
    ) -> CGSize {
        capped(
            body.build(
                content,
                shelf: shelf,
                maxHeight: room(edge: edge, strip: strip, visible: visible),
                // The cut is at the far edge from the bar.
                cutAtTop: edge == .bottom
            ),
            edge: edge,
            strip: strip,
            visible: visible
        )
    }

    /// Where the panel opens: across the strip from the bar's
    /// edge, a gap off it, centred on the item (owner, device) and
    /// kept inside the usable area.
    nonisolated static func origin(
        size: CGSize,
        edge: AppBarEdge,
        anchor: CGRect,
        strip: CGRect,
        visible screen: CGRect
    ) -> CGPoint {
        typealias M = BarPeekBody.Metrics
        var point: CGPoint
        switch edge {
        case .top:
            point = CGPoint(
                x: anchor.midX - size.width / 2,
                y: strip.minY - M.stripGap - size.height
            )
        case .bottom:
            point = CGPoint(
                x: anchor.midX - size.width / 2,
                y: strip.maxY + M.stripGap
            )
        case .left:
            point = CGPoint(
                x: strip.maxX + M.stripGap,
                y: anchor.midY - size.height / 2
            )
        case .right:
            point = CGPoint(
                x: strip.minX - M.stripGap - size.width,
                y: anchor.midY - size.height / 2
            )
        }
        let margin = M.screenMargin
        point.x = min(
            max(point.x, screen.minX + margin),
            max(screen.maxX - margin - size.width, screen.minX + margin)
        )
        point.y = min(
            max(point.y, screen.minY + margin),
            max(screen.maxY - margin - size.height, screen.minY + margin)
        )
        // Whole points, as AppKit frames a window, so the menu the
        // click opens (`BarPeek.menuTopLeft`) meets the peek's edge.
        return CGPoint(x: point.x.rounded(), y: point.y.rounded())
    }

    private func paint(_ shelf: KiwiShelf, edge: AppBarEdge, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        let radius = BarPeekBody.Metrics.cornerRadius
        root.frame = bounds
        if shelf.glassEnabled, let glass = glassView() {
            solid.isHidden = true
            glass.isHidden = false
            GlassPlate.setContent(glass, body)
            GlassPlate.update(glass, frame: bounds, cornerRadius: radius)
            // A reading panel: one tint over its whole height.
            GlassTint.applyUniform(
                tint,
                below: glass,
                frame: bounds,
                cornerRadius: radius,
                hex: shelf.fillColor
            )
            return
        }
        if let glass, GlassPlate.holds(glass, body) {
            GlassPlate.release(glass)
        }
        glass?.isHidden = true
        tint.isHidden = true
        solid.isHidden = false
        solid.frame = bounds
        solid.layer?.cornerRadius = radius
        solid.layer?.backgroundColor =
            NSColor(kiwiHex: shelf.fillColor).cgColor
        if body.superview !== root { root.addSubview(body) }
        body.frame = bounds
    }

    /// The glass, made once beneath the body; nil below 26.
    private func glassView() -> NSView? {
        if let glass { return glass }
        guard let made = GlassPlate.make() else { return nil }
        root.addSubview(made, positioned: .above, relativeTo: solid)
        glass = made
        return made
    }

    private func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        panel.level = BarPanel.aboveLevel
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.setAccessibilityElement(false)
        root.wantsLayer = true
        root.setAccessibilityElement(false)
        solid.wantsLayer = true
        solid.layer?.masksToBounds = true
        root.addSubview(solid)
        root.addSubview(body)
        panel.contentView = root
        return panel
    }
}
