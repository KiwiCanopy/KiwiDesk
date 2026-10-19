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
        let room = ShelfIndicatorSpec.hoverGrowth
        let mark = bounds.insetBy(dx: room, dy: room)
        dots.frame = mark
        dots.spec = spec
        plate.layer?.backgroundColor = NSColor(kiwiHex: spec.fill).cgColor
        rim.ink = .init(
            hex: spec.highlight,
            width: spec.rimWidth,
            sheen: spec.sheen
        )
        BarMotion.placeHoverPlate(
            plate,
            rim: rim,
            mark: mark,
            hovered: spec.hovered,
            animated: animated && was?.hovered != spec.hovered
        )
        // The plate gives way under the shelf it reveals and
        // comes back as the shelf retracts into it.
        if let was, was.standsAside != spec.standsAside, animated {
            BarMotion.fadeMark(
                body,
                showing: !spec.standsAside,
                morphs: spec.morphs
            )
        } else if was?.standsAside != spec.standsAside || !animated {
            body.alphaValue = spec.standsAside ? 0 : 1
        }
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }

    override func accessibilityLabel() -> String? {
        carriesSpaceBar
            ? L("kiwishelf.indicator.space_bar.ax", "Space Bar")
            : L("kiwishelf.indicator.app_bar.ax", "App Bar")
    }

    override func accessibilityValue() -> Any? {
        spec?.shown == true
            ? L("kiwishelf.indicator.shown.ax", "Shown")
            : L("kiwishelf.indicator.hidden.ax", "Hidden")
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
/// resting frame so a hover moves none of them.
final class ShelfIndicatorDots: NSView {
    var spec: ShelfIndicatorSpec? { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let spec, case .dots(let dots) = spec.mark else { return }
        var lead =
            (spec.horizontal ? bounds.minX : bounds.minY)
            + ShelfIndicatorSpec.pad
        let size = ShelfIndicatorSpec.dot
        let cross =
            (spec.horizontal ? bounds.minY : bounds.minX)
            + (ShelfIndicatorSpec.depth - size) / 2
        for dot in dots {
            let long =
                dot.current ? ShelfIndicatorSpec.currentDot : size
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
            lead += long + ShelfIndicatorSpec.dotGap
        }
    }
}
