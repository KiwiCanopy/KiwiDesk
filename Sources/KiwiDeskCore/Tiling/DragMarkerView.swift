import AppKit

/// One drag marker's drawing (#2797): the drop zone an untinted
/// frosted plate with a thin light rim, the ghost a two-tone outline
/// with no fill. The live drag's panels and the Settings picture of
/// them host this one view, so the picture calls the engine rather
/// than re-drawing it (#702, #1645).
@MainActor
public final class DragMarkerView: NSView {
    /// Which marker the view draws.
    public enum Kind: Sendable, Equatable {
        case dropZone
        case ghost
    }

    /// What the drop zone is frosted with, as drawn.
    enum Surface: Equatable {
        /// Liquid Glass, untinted and thinned.
        case glass
        /// The system blur material, where glass is off.
        case material
        /// Flat grey, while transparency is reduced.
        case flat
    }

    private(set) var glass: NSView?
    private(set) var material: NSVisualEffectView?
    let tint = GlassBackdrop()
    /// The ghost's outline: a light halo beneath a dark line.
    let halo = CAShapeLayer()
    let line = CAShapeLayer()
    private var preview: PreviewInput?
    private var gateToken: NSObjectProtocol?

    /// What a Settings picture asked to draw, kept for re-draws.
    private struct PreviewInput {
        let kind: Kind
        let cornerRadius: CGFloat
        let storedGlass: Bool
    }

    /// The drop zone's glass is thinned: it lies over the window a
    /// drop swaps with, which should stay readable through it (owner,
    /// device 2026-09-25). Opacity is the one public strength the
    /// material takes; `.clear` is already its lightest style. The
    /// blur material takes the same opacity.
    static let glassOpacity: CGFloat = 0.6
    /// The drop zone's rim, drawn over every surface.
    static let rimWidth: CGFloat = 1
    static let rimColor = NSColor(white: 1, alpha: 0.5)
    /// The drop zone under Reduce transparency: grey at about 22 %.
    static let flatColor = NSColor(white: 0.5, alpha: 0.22)
    /// The ghost's outline, as the bare pocket mark's edge: a dark
    /// line centred in a wider light halo.
    static let lineWidth: CGFloat = 1.5
    static let lineColor = NSColor(white: 0, alpha: 0.6)
    static let haloWidth: CGFloat = 4
    static let haloColor = NSColor(white: 1, alpha: 0.6)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        for shape in [halo, line] {
            shape.fillColor = nil
            shape.isHidden = true
            layer?.addSublayer(shape)
        }
    }

    public convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// The drop zone's surface for `glass`, already resolved through
    /// `LiquidGlassGate.rendered(glass:)`.
    static func surface(glass: Bool) -> Surface {
        if glass { return .glass }
        return LiquidGlassGate.reducesTransparency ? .flat : .material
    }

    /// Draws `kind` the way a drag draws it. `storedGlass` is the
    /// `dragLiquidGlass` leaf, resolved through the gate at each
    /// draw and re-drawn live when Reduce transparency flips
    /// (#1374).
    public func showPreview(
        _ kind: Kind,
        cornerRadius: CGFloat,
        storedGlass: Bool
    ) {
        preview = PreviewInput(
            kind: kind,
            cornerRadius: cornerRadius,
            storedGlass: storedGlass
        )
        observeGate()
        redrawPreview()
    }

    private func redrawPreview() {
        guard let input = preview else { return }
        render(
            input.kind,
            cornerRadius: input.cornerRadius,
            surface: Self.surface(
                glass: LiquidGlassGate.rendered(glass: input.storedGlass)
            )
        )
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeGate()
    }

    /// A preview in a window hears the gate flip; one out of a
    /// window lets go. Asked on each show too, since a preview
    /// set after the view is already in its window never moves
    /// to one.
    private func observeGate() {
        guard preview != nil else { return }
        if window == nil, let gateToken {
            NSWorkspace.shared.notificationCenter
                .removeObserver(gateToken)
            self.gateToken = nil
        } else if window != nil, gateToken == nil {
            gateToken = LiquidGlassGate.observe { [weak self] in
                self?.redrawPreview()
            }
        }
    }

    public override func layout() {
        super.layout()
        redrawPreview()
    }

    /// A frame-driven host resizes without a layout pass.
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        redrawPreview()
    }

    /// Paints the marker inside its bounds; `surface` is already
    /// resolved and only the drop zone reads it.
    func render(
        _ kind: Kind,
        cornerRadius radius: CGFloat,
        surface: Surface
    ) {
        guard let layer else { return }
        layer.cornerRadius = radius
        switch kind {
        case .ghost:
            layer.borderWidth = 0
            layer.backgroundColor = NSColor.clear.cgColor
            glass?.isHidden = true
            material?.isHidden = true
            outline(radius: radius)
        case .dropZone:
            halo.isHidden = true
            line.isHidden = true
            // A layer's border draws above its sublayers, so the rim
            // stays over the glass and the material.
            layer.borderWidth = Self.rimWidth
            layer.borderColor = Self.rimColor.cgColor
            frost(surface, radius: radius)
        }
    }

    private func frost(_ surface: Surface, radius: CGFloat) {
        let plate = surface == .glass ? glassView() : nil
        let drawn = surface == .glass && plate == nil ? .material : surface
        layer?.backgroundColor =
            drawn == .flat
            ? Self.flatColor.cgColor
            : NSColor.clear.cgColor
        glass?.isHidden = drawn != .glass
        if let plate, drawn == .glass {
            plate.alphaValue = Self.glassOpacity
            GlassPlate.update(plate, frame: bounds, cornerRadius: radius)
            GlassTint.apply(
                tint,
                in: plate,
                cornerRadius: radius,
                fill: GlassFill(hex: ""),
                edge: .top
            )
        }
        guard drawn == .material else {
            material?.isHidden = true
            return
        }
        let blur = materialView()
        blur.isHidden = false
        blur.alphaValue = Self.glassOpacity
        blur.frame = bounds
        blur.layer?.cornerRadius = radius
    }

    /// The ghost's two strokes on one path, inset so the halo stays
    /// inside the slot.
    private func outline(radius: CGFloat) {
        let inset = Self.haloWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else {
            halo.isHidden = true
            line.isHidden = true
            return
        }
        let corner = min(
            max(0, radius - inset),
            rect.width / 2,
            rect.height / 2
        )
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )
        let strokes = [
            (halo, Self.haloWidth, Self.haloColor),
            (line, Self.lineWidth, Self.lineColor),
        ]
        for (shape, width, color) in strokes {
            shape.isHidden = false
            shape.frame = bounds
            shape.path = path
            shape.lineWidth = width
            shape.strokeColor = color.cgColor
        }
    }

    /// The drop zone's glass, hosted once; nil below macOS 26.
    private func glassView() -> NSView? {
        if let glass { return glass }
        guard let plate = GlassPlate.make() else { return nil }
        plate.autoresizingMask = [.width, .height]
        addSubview(plate, positioned: .below, relativeTo: nil)
        glass = plate
        return plate
    }

    /// The drop zone's blur material, hosted once.
    private func materialView() -> NSVisualEffectView {
        if let material { return material }
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        view.autoresizingMask = [.width, .height]
        addSubview(view, positioned: .below, relativeTo: nil)
        material = view
        return view
    }
}
