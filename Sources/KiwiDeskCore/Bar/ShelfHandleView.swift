import AppKit

/// The view a handle draws (#761, #3349), and VoiceOver's way to
/// the show/hide action: its press runs the action and its value
/// says whether the shelf is shown. The plate is a view of its own,
/// so an approach thickens its frame while what peeks through
/// fades in over it.
final class ShelfHandleView: NSView {
    private(set) var spec: ShelfHandleSpec?
    /// The bar the action names, for the label.
    var carriesSpaceBar = true
    var onPress: @MainActor () -> Void = {}

    /// Holds the plate and the peek; it fades out under a shelf
    /// revealing over it and back as it retracts, the view itself
    /// staying for VoiceOver.
    let body = AppBarOverlay.FlippedView()
    let plate = NSView()
    /// What peeks through the thickened plate, at the plate's grown
    /// frame: the Space dots or the App Bar's glyphs.
    let peek = ShelfHandlePeek()
    /// The plate's content slot `BarMotion.placeHoverPlate` moves;
    /// the handle keeps none.
    private let still = NSView()
    /// The thickened plate as tinted glass where its bar draws
    /// glass (#2567): a glass box whose host travels with the plate.
    private(set) var glass: (glass: NSView, tint: GlassBackdrop)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        body.wantsLayer = true
        plate.wantsLayer = true
        addSubview(body)
        body.addSubview(plate)
        body.addSubview(peek)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    /// Draws `spec` in the current bounds — the handle inset by the
    /// thickening's room — thickening the plate where `animated`.
    func render(_ spec: ShelfHandleSpec, animated: Bool) {
        let was = self.spec
        self.spec = spec
        body.frame = bounds
        let mark = ShelfHandle.mark(of: spec, in: bounds)
        peek.spec = spec
        let box = glassBox(for: spec)
        // At rest never the bar's own ink, which vanishes on a light
        // window (#3349, #3357); thickened, the Fill or its glass.
        var rest: CGColor?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            rest = ShelfHandleSpec.restColor(hex: spec.restHex).cgColor
        }
        plate.layer?.backgroundColor =
            spec.hovered
            ? (box == nil
                ? NSColor(kiwiFill: spec.fill.hex).cgColor : nil)
            : rest
        let grown = BarMotion.hoverPlate(
            mark: mark,
            edge: spec.edge,
            hovered: true
        )
        let capsule = min(grown.width, grown.height) / 2
        BarMotion.placeHoverPlate(
            plate,
            rim: peek,
            content: still,
            contentRest: .zero,
            mark: mark,
            edge: spec.edge,
            hovered: spec.hovered,
            animated: animated && was?.hovered != spec.hovered,
            placePlate: { [plate] frame, glides in
                plate.frame = frame
                plate.layer?.cornerRadius =
                    min(frame.width, frame.height) / 2
                guard let box else { return }
                GlassBox.place(
                    box.glass,
                    tint: box.tint,
                    at: frame,
                    cornerRadius: capsule,
                    fill: spec.fill,
                    edge: spec.edge,
                    visible: spec.hovered,
                    animated: glides,
                    // Behind: the glass's edge over a Fill on top
                    // reads as a border (#2569 ▸ owner).
                    behind: true,
                    // The plate's own group carries the motion
                    // (`BarMotion.placeHoverPlate`).
                    move: { host, frame, _ in host.frame = frame }
                )
            }
        )
        // The handle gives way to the shelf it reveals and comes
        // back as the shelf's retract lands.
        if let was, was.standsAside != spec.standsAside, animated {
            BarMotion.fadeMark(
                body,
                showing: !spec.standsAside,
                reveal: spec.reveal
            )
        } else if was?.standsAside != spec.standsAside || !animated {
            body.alphaValue = spec.standsAside ? 0 : 1
        }
    }

    /// The resting hairline's ink follows the appearance.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if let spec { render(spec, animated: false) }
    }

    /// The glass box `spec` draws its thickened plate in, made once
    /// beneath the peek; nil, and any box dropped, where its bar
    /// draws no glass or the OS has none.
    private func glassBox(
        for spec: ShelfHandleSpec
    ) -> (glass: NSView, tint: GlassBackdrop)? {
        guard spec.glass else {
            if let glass { GlassBox.drop(glass.glass, glass.tint) }
            glass = nil
            return nil
        }
        if glass == nil { glass = GlassBox.make(in: body, below: peek) }
        return glass
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    override func accessibilityLabel() -> String? {
        carriesSpaceBar
            ? L("kiwishelf.indicator.space_bar.ax", "Space Bar")
            : L("kiwishelf.indicator.app_bar.ax", "App Bar")
    }

    override func accessibilityValue() -> Any? {
        let shown = spec?.shown == true
        // The dots may not all show, so the place is spoken whole.
        guard let place = spec?.position else {
            return shown
                ? L("kiwishelf.indicator.shown.ax", "Shown")
                : L("kiwishelf.indicator.hidden.ax", "Hidden")
        }
        return shown
            ? L(
                "kiwishelf.indicator.shown_position.ax",
                "Shown, Space %1$d of %2$d",
                place.index,
                place.count
            )
            : L(
                "kiwishelf.indicator.hidden_position.ax",
                "Hidden, Space %1$d of %2$d",
                place.index,
                place.count
            )
    }

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }
}

/// What peeks through a thickened handle (#3349), drawn centred in
/// its own bounds — the grown plate — at `peekAlpha`: the Space
/// dots, or the App Bar's glyphs, their tops past the plate's
/// inner side clipped away.
final class ShelfHandlePeek: NSView {
    var spec: ShelfHandleSpec? { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let spec else { return }
        switch spec.peek {
        case .dots(let dots): draw(dots, spec)
        case .glyphs(let images): draw(images, spec)
        }
    }

    private func draw(
        _ dots: [ShelfHandleSpec.Dot],
        _ spec: ShelfHandleSpec
    ) {
        typealias Size = ShelfHandleSpec
        let lengths = dots.map { dot in
            dot.current
                ? Size.currentDot : dot.small ? Size.smallDot : Size.dot
        }
        let gaps = CGFloat(max(0, dots.count - 1)) * Size.dotGap
        let total = lengths.reduce(0, +) + gaps
        var lead =
            (spec.horizontal ? bounds.midX : bounds.midY) - total / 2
        let middle = spec.horizontal ? bounds.midY : bounds.midX
        for (dot, long) in zip(dots, lengths) {
            let size =
                dot.small ? ShelfHandleSpec.smallDot : ShelfHandleSpec.dot
            let cross = middle - size / 2
            let rect =
                spec.horizontal
                ? CGRect(x: lead, y: cross, width: long, height: size)
                : CGRect(x: cross, y: lead, width: size, height: long)
            NSColor(kiwiHex: spec.ink(of: dot))
                .withAlphaComponent(ShelfHandleSpec.peekAlpha)
                .setFill()
            NSBezierPath(
                roundedRect: rect,
                xRadius: size / 2,
                yRadius: size / 2
            ).fill()
            lead += long + ShelfHandleSpec.dotGap
        }
    }

    private func draw(_ images: [NSImage], _ spec: ShelfHandleSpec) {
        let size = ShelfHandleSpec.glyph
        let step = size + ShelfHandleSpec.glyphGap
        let along = spec.horizontal ? bounds.width : bounds.height
        let gap = ShelfHandleSpec.glyphGap
        let fits = max(0, Int((along + gap) / step))
        let shown = images.prefix(fits)
        let total = CGFloat(shown.count) * step - gap
        var lead =
            (spec.horizontal ? bounds.midX : bounds.midY) - total / 2
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: bounds).setClip()
        for image in shown {
            // Anchored on the plate's inner side and running out
            // past the screen side, so the edge of the glyph the
            // bar brings in first shows, as the reveal will.
            let low = spec.edge == .top || spec.edge == .left
            let rect =
                spec.horizontal
                ? CGRect(
                    x: lead,
                    y: low ? bounds.maxY - size : bounds.minY,
                    width: size,
                    height: size
                )
                : CGRect(
                    x: low ? bounds.maxX - size : bounds.minX,
                    y: lead,
                    width: size,
                    height: size
                )
            image.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: ShelfHandleSpec.peekAlpha,
                respectFlipped: true,
                hints: nil
            )
            lead += step
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
