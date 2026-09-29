import AppKit

/// Visual representation of a space mark (#421).
public enum SpaceMark: Equatable {
    case symbol(String)
    case text(String)
}

/// Visual plate displaying the state glyphs and space pill (#414,
/// #421): one or two squares, the outermost at the right edge and
/// the inner one (floating beside sticky, #1799) left of it. A
/// clipping container: the `.hudWindow` backing or, under Liquid
/// Glass, tinted glass (#1621, `+Glass`), with the glyphs in
/// `content` above either.
@MainActor
final class StickyMarkPlate: NSView {
    /// Collapsed badge square dimension.
    static let size: CGFloat = 20
    /// Padding and gap metrics.
    static let namePad: CGFloat = 8
    static let nameGap: CGFloat = 4
    /// Maximum expanded pill width.
    static let maxWidth: CGFloat = 360
    /// Corner radii for collapsed square and expanded capsule.
    static let collapsedRadius: CGFloat = size / 4
    static let expandedRadius: CGFloat = size / 2

    /// The `.hudWindow` backing; hidden while the mark is glass.
    let hud = NSVisualEffectView()
    /// The glyphs, hosted by the plate or by the glass (#1621).
    let content = NSView()
    /// The glass, hosted once asked for; nil below macOS 26.
    var glass: NSView?
    let tint = GlassBackdrop()
    /// Whether the mark draws as glass (`setGlass`).
    var isGlass = false
    /// The stored colour, kept for the glass tint.
    var markHex = ""

    /// The outermost glyph and its disc (#429).
    let symbol = NSImageView()
    let roundel = NSView()
    /// The inner glyph, its disc and colour (#1799); drawn only
    /// while `slotCount` is 2.
    let innerSymbol = NSImageView()
    let innerRoundel = NSView()
    var innerHex = ""
    /// Glyph squares drawn: 1, or 2 with the inner one.
    var slotCount = 1
    let name = NSTextField(labelWithString: "")
    /// Diameter of background roundel.
    static let roundelSize: CGFloat = 15

    /// Resolved tint color (#429).
    var markColor: NSColor = .labelColor

    init() {
        super.init(
            frame: CGRect(
                x: 0,
                y: 0,
                width: Self.size,
                height: Self.size
            )
        )
        wantsLayer = true
        layer?.cornerRadius = Self.collapsedRadius
        layer?.masksToBounds = true
        hud.material = .hudWindow
        hud.state = .active
        for view in [hud, content, tint] as [NSView] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
        }

        for glyph in [symbol, innerSymbol] {
            glyph.symbolConfiguration =
                NSImage.SymbolConfiguration(
                    pointSize: Self.size * 0.55,
                    weight: .semibold
                )
            glyph.contentTintColor = .labelColor
            glyph.imageScaling = .scaleProportionallyDown
        }
        innerSymbol.isHidden = true

        name.font = .systemFont(ofSize: 11, weight: .semibold)
        name.textColor = .labelColor
        name.drawsBackground = false
        name.isBordered = false
        name.isEditable = false
        name.lineBreakMode = .byTruncatingTail
        name.usesSingleLineMode = true
        name.alphaValue = 0

        for disc in [roundel, innerRoundel] {
            disc.wantsLayer = true
            disc.layer?.cornerRadius = Self.roundelSize / 2
            disc.isHidden = true
        }

        addSubview(hud)
        addSubview(content)
        content.addSubview(name)
        for view in [roundel, symbol, innerRoundel, innerSymbol] {
            content.addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Sets the outermost glyph's hex color — the glass tint and
    /// the pill's ink — and its roundel (#429).
    func setMarkColor(_ hex: String) {
        markHex = hex
        guard !isGlass else {
            applyGlass()
            return
        }
        markColor = Self.paint(symbol, roundel, hex: hex)
        Self.paint(
            innerSymbol,
            innerRoundel,
            hex: slotCount > 1 ? innerHex : ""
        )
        innerRoundel.isHidden = slotCount < 2 || innerHex.isEmpty
        name.textColor = markColor
    }

    /// Shows or hides the inner glyph (#1799), with its colour.
    func setInner(_ image: NSImage?, hex: String) {
        innerSymbol.image = image
        innerHex = hex
        slotCount = image == nil ? 1 : 2
        innerSymbol.isHidden = image == nil
        needsLayout = true
        setMarkColor(markHex)
    }

    /// Paints one glyph on the flat finish: a filled disc under a
    /// contrasting glyph, or the bare label ink on Automatic.
    @discardableResult
    private static func paint(
        _ glyph: NSImageView,
        _ disc: NSView,
        hex: String
    ) -> NSColor {
        guard !hex.isEmpty else {
            disc.isHidden = true
            glyph.contentTintColor = .labelColor
            return .labelColor
        }
        let fill = NSColor(kiwiHex: hex)
        disc.isHidden = false
        disc.layer?.backgroundColor = fill.cgColor
        glyph.contentTintColor = fill.contrastingGlyph
        return fill
    }

    /// Glyph squares that fit a window `width` points wide beside
    /// the traffic lights, of `wanted` (#1799): the inner glyph
    /// drops first, the outermost never.
    static func fittingSlots(_ wanted: Int, windowWidth: CGFloat) -> Int {
        let spare =
            windowWidth - StickyMarkOverlay.inset * 2
            - trafficLightClearance
        return max(1, min(wanted, Int(spare / size)))
    }

    /// Room the traffic lights take at a window's top-left.
    static let trafficLightClearance: CGFloat = 80

    override func layout() {
        super.layout()
        let w = bounds.width
        let inset = (Self.size - Self.roundelSize) / 2
        for (slot, pair) in [(symbol, roundel), (innerSymbol, innerRoundel)]
            .enumerated()
        {
            let x = w - Self.size * CGFloat(slot + 1)
            pair.0.frame = CGRect(
                x: x,
                y: 0,
                width: Self.size,
                height: Self.size
            )
            pair.1.frame = CGRect(
                x: x + inset,
                y: inset,
                width: Self.roundelSize,
                height: Self.roundelSize
            )
        }
        let textHeight = ceil(name.intrinsicContentSize.height)
        let glyphs = Self.size * CGFloat(slotCount)
        let right = w - glyphs - Self.nameGap
        name.frame = CGRect(
            x: Self.namePad,
            y: (Self.size - textHeight) / 2,
            width: max(0, right - Self.namePad),
            height: textHeight
        )
    }

    /// Toggles visibility of space name label and morphs capsule shape.
    func setNameShown(
        _ shown: Bool,
        animated: Bool,
        duration: TimeInterval
    ) {
        let radius =
            shown ? Self.expandedRadius : Self.collapsedRadius
        if animated {
            name.animator().alphaValue = shown ? 1 : 0
            animateCornerRadius(to: radius, over: duration)
        } else {
            name.alphaValue = shown ? 1 : 0
            layer?.cornerRadius = radius
        }
    }

    /// Animates layer corner radius.
    func animateCornerRadius(
        to radius: CGFloat,
        over duration: TimeInterval
    ) {
        guard let layer else { return }
        let anim = CABasicAnimation(keyPath: "cornerRadius")
        anim.fromValue = layer.cornerRadius
        anim.toValue = radius
        anim.duration = duration
        layer.add(anim, forKey: "cornerRadius")
        layer.cornerRadius = radius
    }
}
