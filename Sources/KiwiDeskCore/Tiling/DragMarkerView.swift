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
    private var preview: PreviewInput?
    private var gateToken: NSObjectProtocol?

    /// What a Settings picture asked to draw, kept for re-draws.
    private struct PreviewInput {
        let style: DragVisual
        let radius: CGFloat
        let storedGlass: Bool
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
    }

    public convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Draws `style` the way a drag draws it. `storedGlass` is the
    /// `dragLiquidGlass` leaf, resolved through the gate at each
    /// draw and re-drawn live when Reduce transparency flips
    /// (#1374).
    public func showPreview(
        _ style: DragVisual,
        cornerRadius: CGFloat,
        storedGlass: Bool
    ) {
        preview = PreviewInput(
            style: style,
            radius: cornerRadius,
            storedGlass: storedGlass
        )
        redrawPreview()
    }

    private func redrawPreview() {
        guard let input = preview else { return }
        render(
            input.style,
            radius: input.radius,
            glass: LiquidGlassGate.rendered(glass: input.storedGlass)
        )
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
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

    /// Paints the marker; `glass` is already resolved by the gate.
    func render(_ style: DragVisual, radius: CGFloat, glass: Bool) {
        guard let layer else { return }
        layer.cornerRadius = radius
        // A layer's border draws above its sublayers, so it stays
        // solid over the glass (`DragPairSeparationTests`, #511).
        layer.borderWidth = style.border ? style.borderWidth : 0
        layer.borderColor = Self.color(style.borderColor).cgColor
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
        addSubview(plate)
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
