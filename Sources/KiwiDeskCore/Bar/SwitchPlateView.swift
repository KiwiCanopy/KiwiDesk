import AppKit

/// The Space switch's plate as a view kept across frames: Liquid
/// Glass, tinted as "Tint KiwiHub and plates" says, or the material
/// where glass stands down, with an optional icon at its centre. The
/// plate that flies into the pocket and out (#2680) and the drag
/// ghost (#3583) draw through it, so both stay the slide's plate
/// (`SpaceSlideOverlay`'s `plateView`). Its ground is fixed at init;
/// a holder whose ground changes makes a new one.
@MainActor
final class SwitchPlateView: NSView {
    /// What the plate draws on: Liquid Glass or not, the Fill it
    /// wears there (nil for the untinted `.regular` glass), and the
    /// Fill it wears flat over the material.
    struct Ground: Equatable {
        let glass: Bool
        let tint: GlassFill?
        let frost: FrostFill?
    }

    let ground: Ground
    private let content = NSView()
    private let icon: NSImageView?
    let tint = GlassBackdrop()
    private(set) var glass: NSView?
    private(set) var material: NSVisualEffectView?

    override var isFlipped: Bool { true }

    init(_ ground: Ground, image: NSImage?) {
        self.ground = ground
        icon = image.map { image in
            let view = NSImageView()
            view.image = image
            view.imageScaling = .scaleProportionallyUpOrDown
            return view
        }
        super.init(frame: .zero)
        wantsLayer = true
        if let icon { content.addSubview(icon) }
        if ground.glass,
            let made = GlassPlate.make(regular: ground.tint == nil)
        {
            glass = made
            addSubview(made)
            GlassPlate.setContent(made, content)
        } else {
            let view = FrostPlate.make(content: content, fill: ground.frost)
            material = view
            addSubview(view)
        }
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
        if let glass {
            GlassPlate.update(glass, frame: bounds, cornerRadius: radius)
            if let fill = ground.tint {
                GlassTint.apply(
                    tint,
                    in: glass,
                    cornerRadius: radius,
                    fill: fill,
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
