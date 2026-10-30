import AppKit

/// The pocket mark (#2680, #2776): bare on the screen, never a box.
/// Lit, it wears a two-tone edge — a dark line and a light halo, so
/// one of them reads on any ground — and hovered it lifts. The brief
/// pocket redraws it at each size its nod gives; standing, it nods
/// and lifts by scale.
@MainActor
final class BriefPocketView: NSView {
    /// Carries the light halo and the lift.
    private let content = NSView()
    /// Carries the dark line.
    private let mark = NSImageView()
    /// How the pocket stands; the brief pocket is always `.active`.
    enum Look: Equatable {
        /// No edge.
        case rest
        /// Hovered, or a window a drop would take over it: the edge,
        /// lifted.
        case lit
        /// A window just went in or out: the edge alone.
        case active
    }
    private(set) var look = Look.active
    private var hex = ""

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        content.wantsLayer = true
        mark.wantsLayer = true
        mark.imageScaling = .scaleProportionallyUpOrDown
        content.addSubview(mark)
        addSubview(content)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Wears the mark in `hex`, the pocket mark's colour.
    func wear(markHex hex: String) {
        self.hex = hex
        needsLayout = true
    }

    /// Below this side the mark draws its solid badge form: the
    /// stitch blurs on a thin bar (#2678).
    static let solidBelow: CGFloat = 14

    func setLook(_ look: Look) {
        guard look != self.look else { return }
        self.look = look
        paintLook(animated: true)
    }

    /// The edge's two tones, black and white whatever the mark's
    /// colour (#2776); their blurs are `PocketMarkGeometry`'s.
    static let lineOpacity: Float = 0.55
    static let haloOpacity: Float = 0.85

    private func paintLook(animated: Bool) {
        guard let line = mark.layer, let halo = content.layer else { return }
        let side = mark.frame.width
        line.shadowColor = NSColor.black.cgColor
        line.shadowOffset = .zero
        line.shadowRadius = side * PocketMarkGeometry.lineBlur
        halo.shadowColor = NSColor.white.cgColor
        halo.shadowOffset = .zero
        halo.shadowRadius = side * PocketMarkGeometry.haloBlur
        let lit = look != .rest
        let scale = look == .lit ? PocketMarkGeometry.lift : 1
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        var lift = CATransform3DMakeTranslation(centre.x, centre.y, 0)
        lift = CATransform3DScale(lift, scale, scale, 1)
        lift = CATransform3DTranslate(lift, -centre.x, -centre.y, 0)
        BarMotion.playPocketLight(
            [
                (line, lit ? Self.lineOpacity : 0),
                (halo, lit ? Self.haloOpacity : 0),
            ],
            lift: halo,
            to: lift,
            lighting: lit,
            animated: animated
        )
    }

    /// Swells once about its centre: a window landing in it.
    func nod() {
        guard let layer = content.layer else { return }
        BarMotion.playPocketNod(
            layer,
            centre: CGPoint(x: bounds.midX, y: bounds.midY)
        )
    }

    #if DEBUG
        /// Test-only: the edge, 0 where none draws — the fainter of
        /// its two tones.
        var edgeOpacity: Float {
            guard let line = mark.layer, let halo = content.layer,
                line.shadowRadius > 0, halo.shadowRadius > line.shadowRadius
            else { return 0 }
            return min(line.shadowOpacity, halo.shadowOpacity)
        }
        /// Test-only: the mark's scale.
        var liftScale: CGFloat { content.layer?.sublayerTransform.m11 ?? 1 }
    #endif

    override func layout() {
        super.layout()
        content.frame = bounds
        // A section's slot is narrower than deep: the mark takes the
        // depth's share, kept inside the slot (#2776).
        let long = max(bounds.width, bounds.height)
        let side = min(
            long * PocketMarkGeometry.markShare,
            min(bounds.width, bounds.height)
        )
        let variant: PocketMark = side < Self.solidBelow ? .badge : .mark
        mark.image = variant.image(size: side, hex: hex)
        mark.frame = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        paintLook(animated: false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Automatic ink follows the appearance.
        needsLayout = true
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
