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
    /// The shelf's hover fill, lit while the pointer or a window a
    /// drop would take is over the pocket plate (#2678): flat on a
    /// solid shelf, through `BarHoverFill` on glass.
    private let litFill = NSView()
    private let litGlass = GlassBackdrop()
    /// How the pocket plate stands, as an inactive Space chip does;
    /// the brief pocket is always `.active`.
    enum Look: Equatable {
        /// Ink dimmed down the shelf's ladder, no fill.
        case rest
        /// The chip's hover: its fill, hover ink, full.
        case lit
        /// Full item ink, no fill: a window just went in.
        case active
    }
    private(set) var look = Look.active
    private let solid = NSView()
    private let tint = GlassBackdrop()
    private let rim = ShelfBorder.make()
    private var glass: NSView?
    private var shelf = KiwiShelf()
    /// The count badge takes the mark's upper-left corner rather
    /// than its upper-right, facing into the screen (#2678).
    private var badgeLeading = false
    /// Draws its own plate (the brief pocket, and the pocket under
    /// Hug and Boxed); under Full the shelf's plate runs beneath.
    private var platePiece = true
    private var hex = ""

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        solid.wantsLayer = true
        solid.layer?.masksToBounds = true
        content.wantsLayer = true
        mark.imageScaling = .scaleProportionallyUpOrDown
        litFill.wantsLayer = true
        litFill.isHidden = true
        litFill.setAccessibilityElement(false)
        litGlass.isHidden = true
        content.addSubview(litGlass)
        content.addSubview(litFill)
        content.addSubview(mark)
        count.isBezeled = false
        count.drawsBackground = false
        count.alignment = .center
        count.wantsLayer = true
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
    /// mark's colour, with `badge` on the mark's corner where
    /// non-nil (#2678).
    func wear(
        _ shelf: KiwiShelf,
        markHex hex: String,
        badge text: String? = nil,
        badgeLeading: Bool = false,
        platePiece: Bool = true
    ) {
        self.shelf = shelf
        self.hex = hex
        self.badgeLeading = badgeLeading
        self.platePiece = platePiece
        count.isHidden = text == nil
        count.stringValue = text ?? ""
        count.font = Self.countFont(shelf)
        needsLayout = true
    }

    /// The shelf's own corner at this depth, so a piece reads as
    /// the shelf's plate (#2678).
    private var plateRadius: CGFloat {
        shelf.resolvedCornerRadius(
            forThickness: min(bounds.width, bounds.height)
        )
    }

    /// Below this side the mark draws its solid badge form: the
    /// stitch blurs on a thin bar (#2678).
    static let solidBelow: CGFloat = 14

    /// Hides the count badge while the pocket rises and returns the
    /// rise's token; only the latest rise's landing shows it again,
    /// so an interrupted rise never shows it mid-flight (#2678
    /// review 19).
    func holdBadge() -> Int {
        badgeRise += 1
        count.alphaValue = 0
        return badgeRise
    }

    /// Shows the badge once `rise`, the latest, has landed.
    func releaseBadge(rise: Int) {
        guard rise == badgeRise else { return }
        count.alphaValue = 1
    }
    private(set) var badgeRise = 0

    func setLook(_ look: Look) {
        self.look = look
        paintLook()
    }

    /// The chip's readings: the fill, and the dim that reaches the
    /// mark alone — never the plate, glass or count badge.
    private func paintLook() {
        let lit = look == .lit
        let radius = plateRadius
        litGlass.frame = bounds
        litFill.layer?.cornerRadius = radius
        let glassShown = BarHoverFill.paint(
            litGlass,
            showsHover: lit,
            hex: shelf.hoverFillColor,
            shelf: shelf,
            edge: .top,
            cornerRadius: radius,
            corners: [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
            ]
        )
        litFill.isHidden = !lit || glassShown
        litFill.layer?.backgroundColor =
            NSColor(kiwiHex: shelf.hoverFillColor).cgColor
        count.textColor = NSColor(kiwiHex: shelf.groupBadgeTextColor)
        count.layer?.backgroundColor =
            NSColor(kiwiHex: shelf.groupBadgeColor).cgColor
        mark.alphaValue = look == .rest ? shelf.dimFactor : 1
    }

    /// The count's face, the overflow mark's.
    static func countFont(_ shelf: KiwiShelf) -> NSFont {
        shelf.badgeFont(
            ofSize: OverflowMarkView.textSize,
            emphasis: .semibold
        )
    }

    override func layout() {
        super.layout()
        let radius = plateRadius
        content.frame = bounds
        litFill.frame = bounds
        litFill.layer?.cornerRadius = radius
        let square = min(bounds.width, bounds.height)
        let side = square * BriefPocketPlan.markSide / BriefPocketPlan.side
        let variant: PocketMark = side < Self.solidBelow ? .badge : .mark
        mark.image = variant.image(size: side, hex: hex)
        mark.frame = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        if !count.isHidden {
            count.sizeToFit()
            let height = count.frame.height
            let width = max(height, count.frame.width + height / 2)
            // On the pocket's upper corner facing into the screen,
            // below the kiwis (#2678).
            count.frame = CGRect(
                x: badgeLeading
                    ? mark.frame.minX - width / 3
                    : mark.frame.maxX - width * 2 / 3,
                y: mark.frame.minY + side * 0.35 - height / 2,
                width: width,
                height: height
            )
            count.layer?.cornerRadius = height / 2
        }
        paintPlate(radius: radius)
        paintLook()
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
        rim.isHidden = !platePiece
        guard platePiece else {
            solid.isHidden = true
            glass?.isHidden = true
            if let glass, GlassPlate.holds(glass, content) {
                GlassPlate.release(glass)
            }
            if content.superview !== self {
                addSubview(content, positioned: .above, relativeTo: solid)
            }
            return
        }
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
