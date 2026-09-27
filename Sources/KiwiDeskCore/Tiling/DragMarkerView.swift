import AppKit

/// One drag marker's drawing — border over its fill, or over glass
/// tinted by that fill and fading downward (#1620). The live drag's
/// panels and the Settings picture of them host this one view, so
/// the picture calls the engine rather than re-drawing it (#702,
/// #1645).
@MainActor
public final class DragMarkerView: NSView {
    private(set) var glass: NSView?
    let tint = GlassBackdrop()
    /// The border's sheen (#1644), above the glass like the flat
    /// border it replaces.
    let rim = SheenRimView()
    private var preview: PreviewInput?
    private var gateToken: NSObjectProtocol?

    /// What a Settings picture asked to draw, kept for re-draws.
    private struct PreviewInput {
        let style: DragVisual
        let radius: CGFloat
        let storedGlass: Bool
        let sheen: CGFloat
    }

    /// Both markers' glass is thinned: the drop zone lies over the
    /// window a drop swaps with, which should stay readable through
    /// it, and the ghost matches it (owner, device 2026-09-25).
    /// Opacity is the one public strength the material takes;
    /// `.clear` is already its lightest style.
    static let glassOpacity: CGFloat = 0.6

    public override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        rim.autoresizingMask = [.width, .height]
        addSubview(rim)
    }

    public convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Draws `style` the way a drag draws it. `storedGlass` is the
    /// `dragLiquidGlass` leaf, resolved through the gate at each
    /// draw and re-drawn live when Reduce transparency flips
    /// (#1374); `sheen` is `border.sheen`, which no gate touches
    /// (#1644).
    public func showPreview(
        _ style: DragVisual,
        cornerRadius: CGFloat,
        storedGlass: Bool,
        sheen: CGFloat
    ) {
        preview = PreviewInput(
            style: style,
            radius: cornerRadius,
            storedGlass: storedGlass,
            sheen: sheen
        )
        observeGate()
        redrawPreview()
    }

    private func redrawPreview() {
        guard let input = preview else { return }
        render(
            input.style,
            radius: input.radius,
            glass: LiquidGlassGate.rendered(glass: input.storedGlass),
            sheen: input.sheen
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

    /// Paints the marker; `glass` is already resolved by the gate.
    func render(
        _ style: DragVisual,
        radius: CGFloat,
        glass: Bool,
        sheen: CGFloat
    ) {
        guard let layer else { return }
        layer.cornerRadius = radius
        // A layer's border draws above its sublayers, so it stays
        // solid over the glass (`DragPairSeparationTests`, #511);
        // the sheen's rim takes its place, above the glass too.
        let ramp = sheen != 0 && style.border
        layer.borderWidth = style.border && !ramp ? style.borderWidth : 0
        layer.borderColor = Self.color(style.borderColor).cgColor
        rim.layer?.cornerRadius = radius
        rim.needsDisplay = true
        rim.paint =
            ramp
            ? SheenRimView.Paint(
                hex: style.borderColor,
                width: style.borderWidth,
                strength: sheen
            )
            : nil
        if glass, let plate = glassView() {
            layer.backgroundColor = NSColor.clear.cgColor
            plate.isHidden = false
            plate.alphaValue = Self.glassOpacity
            GlassPlate.update(plate, frame: bounds, cornerRadius: radius)
            GlassTint.apply(
                tint,
                below: plate,
                frame: bounds,
                cornerRadius: radius,
                hex: style.fill ? style.fillColor : "",
                edge: .top
            )
            return
        }
        self.glass?.isHidden = true
        tint.isHidden = true
        layer.backgroundColor =
            style.fill
            ? Self.color(style.fillColor).cgColor
            : NSColor.clear.cgColor
    }

    /// The marker's glass, hosted once; nil below macOS 26.
    private func glassView() -> NSView? {
        if let glass { return glass }
        guard let plate = GlassPlate.make() else { return nil }
        plate.autoresizingMask = [.width, .height]
        tint.autoresizingMask = [.width, .height]
        addSubview(plate, positioned: .below, relativeTo: rim)
        GlassPlate.setContent(plate, NSView())
        glass = plate
        return plate
    }

    /// Colors come as user-set hex strings; a string that no
    /// longer parses falls back to the system accent color.
    private static func color(_ hex: String) -> NSColor {
        guard let c = DragVisual.parseHex(hex) else {
            return .controlAccentColor
        }
        return NSColor(
            srgbRed: c.red,
            green: c.green,
            blue: c.blue,
            alpha: c.alpha
        )
    }
}
