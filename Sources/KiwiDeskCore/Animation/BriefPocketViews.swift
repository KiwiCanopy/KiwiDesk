import AppKit

/// The brief pocket itself (#2680): a rounded plate in KiwiShelf's
/// look — its Fill as tinted glass or solid, and its rim, as the
/// overflow mark wears it — holding the pocket mark, and on the
/// pocket plate the count beside it (#2678). Redrawn at each size
/// the nod gives it, never scaled.
@MainActor
final class BriefPocketView: NSView {
    private let content = NSView()
    private let mark = NSImageView()
    private let count = NSTextField(labelWithString: "")
    /// The shelf's hover fill, lit while a dragged window over the
    /// pocket plate would drop in (#2678).
    private let dropFill = NSView()
    private let solid = NSView()
    private let tint = GlassBackdrop()
    private let rim = ShelfBorder.make()
    private var glass: NSView?
    private var shelf = KiwiShelf()
    /// The mark's square at the trailing end, the count before it.
    private var markTrailing = false

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        solid.wantsLayer = true
        solid.layer?.masksToBounds = true
        content.wantsLayer = true
        mark.imageScaling = .scaleProportionallyUpOrDown
        dropFill.wantsLayer = true
        dropFill.isHidden = true
        dropFill.setAccessibilityElement(false)
        content.addSubview(dropFill)
        content.addSubview(mark)
        count.isBezeled = false
        count.drawsBackground = false
        count.alignment = .center
        count.isHidden = true
        count.setAccessibilityElement(false)
        content.addSubview(count)
        addSubview(solid)
        addSubview(content)
        addSubview(rim)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Wears the gated `shelf` and the mark in `hex`, the pocket
    /// mark's colour, with `text` beside the mark where non-nil —
    /// before it where `markTrailing`.
    func wear(
        _ shelf: KiwiShelf,
        markHex hex: String,
        count text: String? = nil,
        markTrailing: Bool = false
    ) {
        self.shelf = shelf
        self.markTrailing = markTrailing
        mark.image = PocketMark.mark.image(
            size: BriefPocketPlan.markSide,
            hex: hex
        )
        count.isHidden = text == nil
        count.stringValue = text ?? ""
        count.font = Self.countFont(shelf)
        count.textColor = NSColor(kiwiHex: shelf.itemColor)
        needsLayout = true
    }

    /// Lights the pocket as a drop target, as a bar item's hover
    /// lights it.
    func setDropHovered(_ on: Bool) {
        dropFill.isHidden = !on
        dropFill.layer?.backgroundColor =
            NSColor(kiwiHex: shelf.hoverFillColor).cgColor
    }

    /// The count's face, the overflow mark's.
    static func countFont(_ shelf: KiwiShelf) -> NSFont {
        shelf.badgeFont(
            ofSize: OverflowMarkView.textSize,
            emphasis: .semibold
        )
    }

    /// The width `text` adds to the square beside the mark.
    static func countWidth(_ text: String, shelf: KiwiShelf) -> CGFloat {
        let font = countFont(shelf)
        let width = (text as NSString).size(withAttributes: [.font: font])
        return ceil(width.width) + BriefPocketPlan.margin
    }

    override func layout() {
        super.layout()
        let radius = min(bounds.width, bounds.height) * 0.3
        content.frame = bounds
        dropFill.frame = bounds
        dropFill.layer?.cornerRadius = radius
        // The mark keeps a square at one end, where the brief pocket
        // lands; the count takes the rest.
        let square = count.isHidden ? bounds.width : bounds.height
        let side = square * BriefPocketPlan.markSide / BriefPocketPlan.side
        let squareX = markTrailing ? bounds.width - square : 0
        mark.frame = CGRect(
            x: squareX + (square - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        if !count.isHidden {
            count.sizeToFit()
            let height = count.frame.height
            count.frame = CGRect(
                x: markTrailing
                    ? BriefPocketPlan.margin / 2
                    : square - BriefPocketPlan.margin / 2,
                y: BarTextGlyph.originY(
                    centredOn: bounds.midY,
                    for: count,
                    band: .figures,
                    height: height
                ),
                width: bounds.width - square,
                height: height
            )
        }
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
