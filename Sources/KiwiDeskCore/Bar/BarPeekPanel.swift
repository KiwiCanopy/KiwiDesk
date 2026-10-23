import AppKit

/// The peek's one panel (#1946): above the bars, taking the mouse
/// for its rows yet non-activating, so a click on a row never
/// activates KiwiDesk, and key only for a list that grows out of its
/// anchor (#2563, `BarPeekPanel+Morph`); hidden from accessibility,
/// where the glyph's menu is its twin. Its ground is the shelf's
/// plate: glass through `GlassTint.apply`, or the solid Fill.
@MainActor
final class BarPeekPanel {
    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    var panel: BarPeekWindow?
    let body = BarPeekBody()
    /// The count a grown list keeps as its header (#2563).
    let header = BarPeekHeader()
    private let root = NSView()
    /// Everything the panel draws; a grown list's clip (#2563).
    let stage = NSView()
    private let solid = NSView()
    private let tint = GlassBackdrop()
    private var glass: NSView?
    /// The fade-out in flight; its landing orders the panel out
    /// unless a show cleared it meanwhile.
    var leaving: UUID?
    /// What the panel shows; nil while it is closed.
    var drawn: BarPeekContent?
    /// The list grown out of an anchor that shows, or is closing
    /// back into it (#2563); nil for every other peek.
    var morph: Morph?
    /// The grown list's open in flight; its landing restores the
    /// shadow unless a close cleared it meanwhile.
    var opening: UUID?
    /// Seconds on a monotonic clock: the peek's `now`, wired by it.
    var now: @MainActor () -> TimeInterval = { 0 }
    /// The pointer on screen: the peek's `pointerOnScreen`, wired by
    /// it, so a returning anchor re-reads its hover through the
    /// peek's seam.
    var pointer: @MainActor () -> CGPoint = { BarPeekPanel.offScreen }
    /// A point on no screen: the pointer before the peek wires it.
    static let offScreen = CGPoint(x: -1e6, y: -1e6)
    /// Runs a morph's landing after its span — a timer; a test
    /// drains it by hand.
    var land: BarPeekSchedule = { span, body in
        BarMotion.afterReveal(span, body)
    }
    /// The grown list's header pressed to close it (#2563).
    var onClose: @MainActor () -> Void = {}

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
        dropMorph()
        body.reserve = .none
        header.isHidden = true
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
        panel.takesKey = false
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
        panel.ignoresMouseEvents = false
        if !panel.isVisible {
            panel.alphaValue = fades ? 0 : 1
            panel.orderFrontRegardless()
        }
        BarMotion.fadePeek(panel, to: 1, animated: fades)
    }

    /// Closes the peek, fading where `animated`; a grown list
    /// shrinks back into its anchor instead (#2563).
    func hide(animated: Bool) {
        guard morph == nil else {
            closeMorph()
            return
        }
        drawn = nil
        guard let panel, panel.isVisible else { return }
        // A fading peek takes no click.
        panel.ignoresMouseEvents = true
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
    /// side of the strip, the panel's size.
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
        // Whole points, as AppKit frames a window.
        return CGPoint(x: point.x.rounded(), y: point.y.rounded())
    }

    func paint(_ shelf: KiwiShelf, edge: AppBarEdge, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        let radius = BarPeekBody.Metrics.cornerRadius
        root.frame = bounds
        stage.frame = bounds
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
        if body.superview !== stage {
            stage.addSubview(body, positioned: .below, relativeTo: header)
        }
        body.frame = bounds
    }

    /// The glass, made once beneath the body; nil below 26.
    private func glassView() -> NSView? {
        if let glass { return glass }
        guard let made = GlassPlate.make() else { return nil }
        stage.addSubview(made, positioned: .above, relativeTo: solid)
        glass = made
        return made
    }

    func makePanel() -> BarPeekWindow {
        GlassActiveAppearance.install()
        let panel = BarPanel.configure(
            BarPeekWindow(
                contentRect: .zero,
                styleMask: BarPanel.styleMask,
                backing: .buffered,
                defer: true
            )
        )
        panel.level = BarPanel.aboveLevel
        panel.hasShadow = true
        panel.setAccessibilityElement(false)
        panel.onKey = { [weak self] in self?.morphKey($0) ?? false }
        root.wantsLayer = true
        root.setAccessibilityElement(false)
        stage.wantsLayer = true
        // The morph fades the rows on the body's own layer.
        body.wantsLayer = true
        solid.wantsLayer = true
        solid.layer?.masksToBounds = true
        root.addSubview(stage)
        stage.addSubview(solid)
        stage.addSubview(body)
        stage.addSubview(header)
        header.isHidden = true
        header.onPress = { [weak self] in self?.headerPressed($0) }
        panel.contentView = root
        return panel
    }
}
