import AppKit

/// The Space switch's plate as a view kept across frames: Liquid
/// Glass, tinted as "Tint KiwiHub and plates" says, or the material
/// where glass stands down, with an optional icon at its centre. The
/// plate that flies into the pocket and out (#2680) and the drag
/// ghost (#3583) draw through it. The slide's plates (#1956) are
/// minted fresh as direct members of a pile's glass container, so
/// they take only the two statics — `surface` and `dress` — which
/// hold every decision a plate's look makes. Its ground is fixed at
/// init; a holder whose ground changes makes a new one.
@MainActor
final class SwitchPlateView: NSView {
    /// What the plate draws on: Liquid Glass or not, the Fill it
    /// wears there (nil for the untinted `.regular` glass), and the
    /// Fill it wears flat over the material.
    struct Ground: Equatable {
        let glass: Bool
        let tint: GlassFill?
        let frost: FrostFill?

        init(glass: Bool, tint: GlassFill?, frost: FrostFill?) {
            self.glass = glass
            self.tint = tint
            self.frost = frost
        }

        /// The ground a plate wears for `shelf`, `glass` being the
        /// surface's own leaf already through the gate (#2569).
        @MainActor
        init(shelf: KiwiShelf, glass: Bool) {
            let ground = LiquidGlassGate.panelGround(shelf, glass: glass)
            self.init(
                glass: glass,
                tint: shelf.glassFill(on: ground),
                frost: ground.frost
            )
        }
    }

    let ground: Ground
    private let content = NSView()
    private let icon: NSImageView?
    let tint = GlassBackdrop()
    private let plate: NSView

    /// The plate's glass, nil where it draws the material.
    var glass: NSView? { GlassPlate.isGlass(plate) ? plate : nil }
    /// The plate's material, nil where it draws glass.
    var material: NSVisualEffectView? { plate as? NSVisualEffectView }

    override var isFlipped: Bool { true }

    init(_ ground: Ground, image: NSImage?) {
        self.ground = ground
        icon = image.map { image in
            let view = NSImageView()
            view.image = image
            view.imageScaling = .scaleProportionallyUpOrDown
            return view
        }
        if let icon { content.addSubview(icon) }
        plate = Self.surface(ground, content: content)
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(plate)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Places the plate at `rect` in its superview, drawn there with
    /// `cornerRadius` and an icon `iconSide` points square.
    func place(
        _ rect: CGRect,
        cornerRadius radius: CGFloat,
        iconSide side: CGFloat,
        host: NSAppearance
    ) {
        frame = rect
        let bounds = CGRect(origin: .zero, size: rect.size)
        content.frame = bounds
        icon?.frame = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        Self.dress(
            plate,
            on: ground,
            tint: tint,
            frame: bounds,
            cornerRadius: radius,
            host: host
        )
    }

    /// A plate's surface on `ground`, hosting `content`: `.clear`
    /// glass under a Fill, `.regular` glass without one, else the
    /// material wearing the Fill flat (`FrostPlate`).
    static func surface(_ ground: Ground, content: NSView) -> NSView {
        if ground.glass,
            let glass = GlassPlate.make(regular: ground.tint == nil)
        {
            GlassPlate.setContent(glass, content)
            return glass
        }
        return FrostPlate.make(content: content, fill: ground.frost)
    }

    /// Frames a `surface` at `frame` with `cornerRadius`, the Fill
    /// fading from the top through `tint`, or the glass following
    /// the Appearance pick where it wears none.
    static func dress(
        _ surface: NSView,
        on ground: Ground,
        tint: GlassBackdrop,
        frame: CGRect,
        cornerRadius radius: CGFloat,
        host: NSAppearance
    ) {
        guard GlassPlate.isGlass(surface) else {
            surface.frame = frame
            surface.layer?.cornerRadius = radius
            return
        }
        GlassPlate.update(surface, frame: frame, cornerRadius: radius)
        guard let fill = ground.tint else {
            GlassTint.followPick(surface, host: host)
            return
        }
        GlassTint.apply(
            tint,
            in: surface,
            cornerRadius: radius,
            fill: fill,
            edge: .top,
            host: host
        )
    }
}
