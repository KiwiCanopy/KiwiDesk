import AppKit

/// The view an indicator draws (#761), and VoiceOver's way to the
/// show/hide action: its press runs the action and its value says
/// whether the shelf is shown. The plate is a view of its own, so
/// the hover grows its frame while the dots stay where they are.
final class ShelfIndicatorView: NSView {
    private(set) var spec: ShelfIndicatorSpec?
    /// The bar the action names, for the label.
    var carriesSpaceBar = true
    var onPress: @MainActor () -> Void = {}

    /// Holds the plate and the dots; it fades out under a shelf
    /// revealing over it and back as it retracts, the view itself
    /// staying for VoiceOver.
    let body = AppBarOverlay.FlippedView()
    let plate = NSView()
    let rim = ShelfIndicatorRim()
    let dots = ShelfIndicatorDots()
    /// The plate as tinted glass where its bar draws glass (#2567):
    /// a glass box whose host travels with the hover, under the rim.
    private(set) var glass: (glass: NSView, tint: GlassBackdrop)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        body.wantsLayer = true
        plate.wantsLayer = true
        addSubview(body)
        body.addSubview(plate)
        body.addSubview(rim)
        body.addSubview(dots)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    /// Draws `spec` in the current bounds — the mark inset by the
    /// hover's room — growing the plate where `animated`.
    func render(_ spec: ShelfIndicatorSpec, animated: Bool) {
        let was = self.spec
        self.spec = spec
        body.frame = bounds
        let mark = ShelfIndicator.mark(of: spec, in: bounds)
        // The dots reach out past the screen side by the hover's
        // shift, so they can follow the plate's middle inward.
        let shift = BarMotion.hoverShift(
            spec.edge,
            across: spec.growth.across
        )
        let dotsRest = bounds.union(
            bounds.offsetBy(dx: -shift.dx, dy: -shift.dy)
        )
        dots.mark = mark.offsetBy(dx: -dotsRest.minX, dy: -dotsRest.minY)
        dots.spec = spec
        plate.layer?.backgroundColor = NSColor(kiwiHex: spec.fill).cgColor
        rim.ink = .init(
            hex: spec.highlight,
            width: spec.rimWidth,
            sheen: spec.sheen
        )
        let box = glassBox(for: spec)
        plate.isHidden = box != nil
        // One radius at both sizes: the box writes it before its
        // host moves, so the grown plate's capsule rounds the
        // resting mark too.
        let grown = BarMotion.hoverPlate(
            mark: mark,
            growth: spec.growth,
            edge: spec.edge,
            hovered: true
        )
        let capsule = min(grown.width, grown.height) / 2
        BarMotion.placeHoverPlate(
            box.flatMap { GlassBox.host(of: $0.glass) } ?? plate,
            rim: rim,
            content: dots,
            contentRest: dotsRest,
            mark: mark,
            growth: spec.growth,
            edge: spec.edge,
            hovered: spec.hovered,
            animated: animated && was?.hovered != spec.hovered,
            placePlate: box.map { box in
                { frame, glides in
                    GlassBox.place(
                        box.glass,
                        tint: box.tint,
                        at: frame,
                        cornerRadius: capsule,
                        hex: spec.fill,
                        edge: spec.edge,
                        visible: true,
                        animated: glides,
                        // The mark's own hover group carries the
                        // motion (`BarMotion.placeHoverPlate`).
                        move: { host, frame, _ in host.frame = frame }
                    )
                }
            }
        )
        // The mark gives way to the shelf it reveals and comes
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

    /// The glass box `spec` draws its plate in, made once beneath
    /// the rim; nil, and any box dropped, where its bar draws no
    /// glass or the OS has none.
    private func glassBox(
        for spec: ShelfIndicatorSpec
    ) -> (glass: NSView, tint: GlassBackdrop)? {
        guard spec.glass else {
            if let glass { GlassBox.drop(glass.glass, glass.tint) }
            glass = nil
            return nil
        }
        if glass == nil { glass = GlassBox.make(in: body, below: rim) }
        return glass
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }

    override func accessibilityLabel() -> String? {
        carriesSpaceBar
            ? L("kiwishelf.indicator.space_bar.ax", "Space Bar")
            : L("kiwishelf.indicator.app_bar.ax", "App Bar")
    }

    override func accessibilityValue() -> Any? {
        let shown = spec?.shown == true
        // The App Bar's count is spoken at rest too, number last.
        if let windows = spec?.count?.windows {
            return shown
                ? L(
                    "kiwishelf.indicator.shown_windows.ax",
                    "Shown, windows: %1$d",
                    windows
                )
                : L(
                    "kiwishelf.indicator.hidden_windows.ax",
                    "Hidden, windows: %1$d",
                    windows
                )
        }
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

/// The hovered plate's rim in the highlight colour and the bars'
/// sheen, stroked inside its own bounds — drawn, never a layer
/// border, which is the shelf border's one painter's (bars.md).
final class ShelfIndicatorRim: NSView {
    struct Ink: Equatable {
        let hex: String
        let width: CGFloat
        let sheen: CGFloat
    }

    var ink: Ink? {
        didSet { if ink != oldValue { needsDisplay = true } }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ink,
            let context = NSGraphicsContext.current?.cgContext
        else { return }
        let inset = ink.width / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else { return }
        let radius = min(rect.width, rect.height) / 2
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        // Sheen 0 is the flat colour throughout.
        BorderSheen.draw(
            path,
            lineWidth: ink.width,
            extent: bounds,
            hex: ink.hex,
            strength: ink.sheen,
            in: context
        )
    }
}

/// The Space dots on an indicator's plate, drawn over the mark's
/// resting frame: a hover widens the current one into the label's
/// pill about the row's middle, the others moving out by half the
/// widening each side.
final class ShelfIndicatorDots: NSView {
    var spec: ShelfIndicatorSpec? { didSet { needsDisplay = true } }
    /// The mark's resting frame in this view.
    var mark: CGRect = .zero { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let spec else { return }
        guard case .dots(let dots) = spec.mark else {
            drawCount(spec)
            return
        }
        let labelled = spec.hovered && spec.label != nil
        let extra = labelled ? spec.labelExtra : 0
        var lead =
            (spec.horizontal ? mark.minX : mark.minY)
            + ShelfIndicatorSpec.pad - extra / 2
        let middle = spec.horizontal ? mark.midY : mark.midX
        for dot in dots {
            let pill = dot.current && labelled
            let size =
                pill
                ? spec.pillDepth
                : dot.small
                    ? ShelfIndicatorSpec.smallDot : ShelfIndicatorSpec.dot
            let long =
                dot.current
                ? ShelfIndicatorSpec.currentDot + extra : size
            let cross = middle - size / 2
            let rect =
                spec.horizontal
                ? CGRect(x: lead, y: cross, width: long, height: size)
                : CGRect(x: cross, y: lead, width: size, height: long)
            NSColor(kiwiHex: spec.ink(of: dot)).setFill()
            NSBezierPath(
                roundedRect: rect,
                xRadius: size / 2,
                yRadius: size / 2
            ).fill()
            if pill, let label = spec.label {
                // Ink against the pill itself, never the shelf's
                // translucent fill, which read faint on a light pill.
                draw(
                    label,
                    in: rect,
                    ink: NSColor(kiwiHex: spec.ink(of: dot))
                        .contrastingGlyph
                )
            }
            lead += long + ShelfIndicatorSpec.dotGap
        }
    }

    /// The label centred in its pill: text by its ink
    /// (`BarTextGlyph.Metrics`) on its band's baseline
    /// (`BarTextGlyph.lineTop`), a symbol by its image.
    private func draw(
        _ label: ShelfIndicatorSpec.Label,
        in pill: CGRect,
        ink color: NSColor
    ) {
        switch label.glyph {
        case .symbol(let name):
            guard
                let image = ShelfIndicatorSpec.symbol(name, font: label.font)
            else { return }
            let tinted = NSImage(size: image.size, flipped: false) { rect in
                image.draw(in: rect)
                color.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(
                in: CGRect(
                    x: pill.midX - image.size.width / 2,
                    y: pill.midY - image.size.height / 2,
                    width: image.size.width,
                    height: image.size.height
                )
            )
        case .text(let text, let tinted):
            var attributes: [NSAttributedString.Key: Any] = [
                .font: label.font
            ]
            if tinted { attributes[.foregroundColor] = color }
            let metrics = BarTextGlyph.metrics(text, font: label.font)
            (text as NSString).draw(
                at: CGPoint(
                    x: metrics.originX(
                        centringInkOn: pill.midX,
                        frameWidth: metrics.advance
                    ),
                    y: BarTextGlyph.lineTop(
                        centredOn: pill.midY,
                        band: .of(identifier: text),
                        font: label.font
                    )
                ),
                withAttributes: attributes
            )
        }
    }
}
