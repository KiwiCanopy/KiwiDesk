import AppKit

/// The brief pocket itself (#2680): a rounded plate in KiwiShelf's
/// look — its Fill as tinted glass or solid, and its rim, as the
/// overflow mark wears it — holding the pocket mark. Redrawn at
/// each size the nod gives it, never scaled.
@MainActor
final class BriefPocketView: NSView {
    private let content = NSView()
    private let mark = NSImageView()
    private let solid = NSView()
    private let tint = GlassBackdrop()
    private let rim = ShelfBorder.make()
    private var glass: NSView?
    private var shelf = KiwiShelf()

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        solid.wantsLayer = true
        solid.layer?.masksToBounds = true
        content.wantsLayer = true
        mark.imageScaling = .scaleProportionallyUpOrDown
        content.addSubview(mark)
        addSubview(solid)
        addSubview(content)
        addSubview(rim)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Wears the gated `shelf` and the mark in `hex`, the pocket
    /// mark's colour.
    func wear(_ shelf: KiwiShelf, markHex hex: String) {
        self.shelf = shelf
        mark.image = PocketMark.mark.image(
            size: BriefPocketPlan.markSide,
            hex: hex
        )
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let radius = min(bounds.width, bounds.height) * 0.3
        content.frame = bounds
        let side =
            bounds.width * BriefPocketPlan.markSide
            / BriefPocketPlan.side
        mark.frame = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        paintPlate(radius: radius)
        rim.frame = bounds
        ShelfBorder.paint(
            rim,
            shelf: shelf,
            surface: shelf.drawsPlate ? .plate : .box,
            under: nil,
            cornerRadius: radius,
            sheen: 0
        )
    }

    private func paintPlate(radius: CGFloat) {
        if shelf.glassEnabled, let glass = glassView() {
            solid.isHidden = true
            glass.isHidden = false
            GlassPlate.setContent(glass, content)
            GlassPlate.update(glass, frame: bounds, cornerRadius: radius)
            GlassTint.apply(
                tint,
                in: glass,
                cornerRadius: radius,
                fill: shelf.glassFill,
                edge: .top
            )
            return
        }
        if let glass, GlassPlate.holds(glass, content) {
            GlassPlate.release(glass)
        }
        glass?.isHidden = true
        solid.isHidden = false
        solid.frame = bounds
        solid.layer?.cornerRadius = radius
        solid.layer?.backgroundColor =
            NSColor(kiwiFill: shelf.fillColor).cgColor
        if content.superview !== self {
            addSubview(content, positioned: .above, relativeTo: solid)
        }
    }

    private func glassView() -> NSView? {
        if let glass { return glass }
        guard let made = GlassPlate.make() else { return nil }
        addSubview(made, positioned: .below, relativeTo: rim)
        glass = made
        return made
    }
}

/// The plate that flies into the pocket and out (#2680): the Space
/// switch's plate — Liquid Glass, tinted as "Tint KiwiHub and
/// plates" says, or the material where glass stands down — with
/// the app's icon at its centre. Drawn in our own overlay, never a
/// capture of the window, and redrawn at each size.
@MainActor
final class BriefPocketPlateView: NSView {
    private let content = NSView()
    private let icon = NSImageView()
    private let tint = GlassBackdrop()
    private var glass: NSView?
    private var material: NSVisualEffectView?
    private var tintFill: GlassFill?

    override var isFlipped: Bool { true }

    /// `glass`: whether the plate draws Liquid Glass; `tintFill`:
    /// the Fill it wears, nil for the untinted `.regular` glass.
    init(glass drawsGlass: Bool, tint tintFill: GlassFill?, image: NSImage?) {
        self.tintFill = tintFill
        super.init(frame: .zero)
        wantsLayer = true
        icon.image = image
        icon.imageScaling = .scaleProportionallyUpOrDown
        content.addSubview(icon)
        if drawsGlass,
            let made = GlassPlate.make(regular: tintFill == nil)
        {
            glass = made
            addSubview(made)
            GlassPlate.setContent(made, content)
        } else {
            let view = NSVisualEffectView()
            view.material = .popover
            view.blendingMode = .behindWindow
            view.state = .active
            view.wantsLayer = true
            view.layer?.masksToBounds = true
            view.addSubview(content)
            material = view
            addSubview(view)
        }
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Places the plate at `rect` in its superview, drawn there.
    func place(_ rect: CGRect, host: NSAppearance) {
        frame = rect
        let bounds = CGRect(origin: .zero, size: rect.size)
        let radius = BriefPocketPlan.plateRadius(for: rect)
        let side = BriefPocketPlan.iconSide(on: rect)
        content.frame = bounds
        icon.frame = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        if let glass {
            GlassPlate.update(glass, frame: bounds, cornerRadius: radius)
            if let tintFill {
                GlassTint.apply(
                    tint,
                    in: glass,
                    cornerRadius: radius,
                    fill: tintFill,
                    edge: .top,
                    host: host
                )
            } else {
                GlassTint.followPick(glass, host: host)
            }
        }
        if let material {
            material.frame = bounds
            material.layer?.cornerRadius = radius
        }
    }
}
