import AppKit

/// One drag marker's drawing (#3583): the drop zone a flat wash of
/// the focus border colour with a hairline of it; the ghost the
/// plate a Space switch slides a window as, without its icon — the
/// shelf's Fill on clear glass under "Tint KiwiHub and plates", else
/// untinted glass, else the material. The live drag's panels and the
/// Settings picture of them host this one view, so the picture calls
/// the engine rather than re-drawing it (#702, #1645).
@MainActor
public final class DragMarkerView: NSView {
    /// Which marker the view draws.
    public enum Kind: Sendable, Equatable {
        case dropZone
        case ghost
    }

    private(set) var glass: NSView?
    private(set) var material: NSVisualEffectView?
    let tint = GlassBackdrop()
    /// What the hosted glass and material were made for: each is
    /// minted again only when it changes, since a drag draws per
    /// pointer move.
    private var glassRegular: Bool?
    private var materialFill: FrostFill??
    private var preview: PreviewInput?
    private var gateToken: NSObjectProtocol?

    /// What a Settings picture asked to draw, kept for re-draws.
    private struct PreviewInput {
        let kind: Kind
        let look: DragMarkerLook
    }

    /// The drop zone: a flat wash and a hairline of the focus
    /// colour, no glass, so the window a drop swaps with stays sharp
    /// beneath it (owner, #3583).
    static let washAlpha: CGFloat = 0.25
    static let edgeAlpha: CGFloat = 0.8
    static let edgeWidth: CGFloat = 1

    public override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    public convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Draws `kind` the way a drag draws it, re-drawn live when
    /// Reduce transparency flips (#1374).
    public func showPreview(_ kind: Kind, look: DragMarkerLook) {
        preview = PreviewInput(kind: kind, look: look)
        observeGate()
        redrawPreview()
    }

    private func redrawPreview() {
        guard let input = preview else { return }
        render(input.kind, look: input.look)
    }

    /// Paints `kind` in `look`, the glass leaf resolved through the
    /// gate here alone; the one door the overlay and the picture
    /// both take.
    func render(_ kind: Kind, look: DragMarkerLook) {
        switch kind {
        case .dropZone:
            renderDropZone(look)
        case .ghost:
            renderGhost(
                look,
                glass: LiquidGlassGate.rendered(glass: look.storedGlass)
            )
        }
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

    /// The focus colour at full alpha; the drop zone sets its own.
    static func focusInk(_ hex: String) -> NSColor {
        let color =
            KiwiShelf.hasColour(hex)
            ? NSColor(kiwiHex: hex) : NSColor.controlAccentColor
        return color.withAlphaComponent(1)
    }

    /// Paints the drop zone: the wash on the layer, the hairline as
    /// its border.
    func renderDropZone(_ look: DragMarkerLook) {
        guard let layer else { return }
        let ink = Self.focusInk(look.focusColor)
        layer.cornerRadius = look.cornerRadius
        layer.backgroundColor =
            ink.withAlphaComponent(Self.washAlpha).cgColor
        layer.borderWidth = Self.edgeWidth
        layer.borderColor = ink.withAlphaComponent(Self.edgeAlpha).cgColor
        glass?.isHidden = true
        material?.isHidden = true
    }

    /// Paints the ghost as a Space-switch plate on the ground Core
    /// answers for the shelf and `drawsGlass` (already through the
    /// gate): the composition `SpaceSlideOverlay`'s `plateView`
    /// makes, with no icon. A tinted plate's panel wears the
    /// key-window rim (#2569).
    func renderGhost(_ look: DragMarkerLook, glass drawsGlass: Bool) {
        guard let layer else { return }
        let radius = look.cornerRadius
        layer.cornerRadius = radius
        layer.borderWidth = 0
        layer.backgroundColor = NSColor.clear.cgColor
        let ground = LiquidGlassGate.panelGround(
            look.shelf,
            glass: drawsGlass
        )
        let fill = look.shelf.glassFill(on: ground)
        (window as? ActiveGlassPanel)?.wearsActiveLook = fill != nil
        if drawsGlass, let plate = glassView(regular: fill == nil) {
            material?.isHidden = true
            plate.isHidden = false
            GlassPlate.update(plate, frame: bounds, cornerRadius: radius)
            let host = window?.effectiveAppearance ?? effectiveAppearance
            guard let fill else {
                GlassTint.followPick(plate, host: host)
                return
            }
            GlassTint.apply(
                tint,
                in: plate,
                cornerRadius: radius,
                fill: fill,
                edge: .top,
                host: host
            )
            return
        }
        glass?.isHidden = true
        let frost = materialView(fill: ground.frost)
        frost.isHidden = false
        frost.frame = bounds
        frost.layer?.cornerRadius = radius
    }

    /// The ghost's glass, minted again when its variant changes;
    /// nil below macOS 26.
    private func glassView(regular: Bool) -> NSView? {
        if let glass, glassRegular == regular { return glass }
        glass?.removeFromSuperview()
        glass = nil
        guard let plate = GlassPlate.make(regular: regular) else {
            return nil
        }
        plate.autoresizingMask = [.width, .height]
        addSubview(plate, positioned: .below, relativeTo: nil)
        glass = plate
        glassRegular = regular
        return plate
    }

    /// The ghost's material, wearing `fill` flat as a plate's does
    /// (`FrostPlate`), minted again when the Fill changes.
    private func materialView(fill: FrostFill?) -> NSVisualEffectView {
        if let material, materialFill == .some(fill) { return material }
        material?.removeFromSuperview()
        let view = FrostPlate.make(content: NSView(), fill: fill)
        view.autoresizingMask = [.width, .height]
        addSubview(view, positioned: .below, relativeTo: nil)
        material = view
        materialFill = .some(fill)
        return view
    }
}
