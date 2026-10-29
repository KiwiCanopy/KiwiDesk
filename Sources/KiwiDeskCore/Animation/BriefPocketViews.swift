import AppKit

/// The brief pocket itself (#2680): a rounded plate in KiwiShelf's
/// look — its Fill as tinted glass or solid, and its rim, as the
/// overflow mark wears it — holding the pocket mark. Redrawn at
/// each size the nod gives it, never scaled.
@MainActor
final class BriefPocketView: NSView {
    private let content = NSView()
    private let mark = NSImageView()
    /// The mark again beneath it, carrying the soft edge's wider
    /// layer: two shadows stack where one stays faint (#2776).
    private let halo = NSImageView()
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
        halo.imageScaling = .scaleProportionallyUpOrDown
        halo.isHidden = true
        litFill.wantsLayer = true
        litFill.isHidden = true
        litFill.setAccessibilityElement(false)
        litGlass.isHidden = true
        content.addSubview(litGlass)
        content.addSubview(litFill)
        content.addSubview(halo)
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
    func wear(
        _ shelf: KiwiShelf,
        markHex hex: String,
        platePiece: Bool = true
    ) {
        self.shelf = shelf
        self.hex = hex
        self.platePiece = platePiece
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

    func setLook(_ look: Look) {
        self.look = look
        paintLook()
    }

    /// The chip's readings: the fill, and the dim that reaches the
    /// mark alone — never the plate or glass.
    private func paintLook() {
        // A bare mark lights by its ink alone: no box (#2776).
        let lit = look == .lit && platePiece
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
        mark.alphaValue = look == .rest ? shelf.dimFactor : 1
        paintEdge()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Automatic ink, and with it the edge, follows the appearance.
        needsLayout = true
    }

    /// A bare mark's soft edge in its stitch's ink, which holds the
    /// bag's shape on a window of its own ink: lit or a window just
    /// in, never at rest (owner, #2776 ▸ D).
    private func paintEdge() {
        mark.wantsLayer = true
        halo.wantsLayer = true
        guard let inner = mark.layer, let outer = halo.layer else { return }
        let drawn = !platePiece && look != .rest
        halo.isHidden = !drawn
        guard drawn else {
            inner.shadowOpacity = 0
            return
        }
        let ink = NSColor.mark(hex: hex, fallback: .labelColor)
        var edge = NSColor.black
        effectiveAppearance.performAsCurrentDrawingAppearance {
            edge = PocketMark.opaque(ink).contrastingGlyph
        }
        let side = mark.frame.width
        for (layer, blur) in [(inner, Self.edgeBlur), (outer, Self.haloBlur)] {
            layer.shadowColor = edge.cgColor
            layer.shadowOpacity = 1
            layer.shadowOffset = .zero
            layer.shadowRadius = side * blur
        }
    }

    /// The edge's two blurs, as shares of the mark's side: a dense
    /// inner one and a wider one beneath.
    static let edgeBlur: CGFloat = 0.06
    static let haloBlur: CGFloat = 0.13

    #if DEBUG
        /// Test-only: whether a hover box draws, flat or on glass.
        var drawsLitBox: Bool { !litFill.isHidden || !litGlass.isHidden }
        /// Test-only: the bare mark's edge, 0 where none draws.
        var edgeOpacity: Float {
            halo.isHidden ? 0 : mark.layer?.shadowOpacity ?? 0
        }
    #endif

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
        halo.image = mark.image
        halo.frame = mark.frame
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
