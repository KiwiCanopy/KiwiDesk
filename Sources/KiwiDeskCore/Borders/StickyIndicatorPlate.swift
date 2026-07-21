import AppKit

/// The sticky mark's rounded plate (#414/#421): the sticky glyph
/// pinned in the rightmost square, and a home-space name to its
/// left, hidden until the chip flashes into a pill. Lays its two
/// subviews out from the live bounds in `layout()` — called on
/// every step of the plate's width animation — so the glyph holds
/// its screen position while the name stretches into view.
@MainActor
final class StickyIndicatorPlate: NSVisualEffectView {
    /// Collapsed chip square; the glyph always occupies the
    /// rightmost square of this side.
    static let size: CGFloat = 20
    /// Padding left of the name, and the gap between name and
    /// glyph.
    static let namePad: CGFloat = 8
    static let nameGap: CGFloat = 4
    /// Max pill width; a longer space name tail-truncates rather
    /// than sprawling across the title bar.
    static let maxWidth: CGFloat = 160
    /// Collapsed reads as a rounded square badge, expanded as a
    /// full capsule — the shape change is the "shows more" signal.
    static let collapsedRadius: CGFloat = size / 4
    static let expandedRadius: CGFloat = size / 2

    let symbol = NSImageView()
    let name = NSTextField(labelWithString: "")

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
        material = .hudWindow
        state = .active
        layer?.cornerRadius = Self.collapsedRadius
        layer?.masksToBounds = true

        symbol.symbolConfiguration =
            NSImage.SymbolConfiguration(
                pointSize: Self.size * 0.55,
                weight: .semibold
            )
        symbol.contentTintColor = .labelColor
        symbol.imageScaling = .scaleProportionallyDown

        name.font = .systemFont(ofSize: 11, weight: .semibold)
        name.textColor = .labelColor
        name.drawsBackground = false
        name.isBordered = false
        name.isEditable = false
        name.lineBreakMode = .byTruncatingTail
        name.usesSingleLineMode = true
        name.alphaValue = 0

        addSubview(name)
        addSubview(symbol)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let w = bounds.width
        symbol.frame = CGRect(
            x: w - Self.size,
            y: 0,
            width: Self.size,
            height: Self.size
        )
        let textHeight = ceil(name.intrinsicContentSize.height)
        let right = w - Self.size - Self.nameGap
        name.frame = CGRect(
            x: Self.namePad,
            y: (Self.size - textHeight) / 2,
            width: max(0, right - Self.namePad),
            height: textHeight
        )
    }

    /// The expanded pill width for `text`, capped so a long name
    /// truncates instead of sprawling.
    func expandedWidth(for text: String) -> CGFloat {
        name.stringValue = text
        let cap =
            Self.maxWidth - Self.namePad - Self.nameGap - Self.size
        let measured = min(
            ceil(name.intrinsicContentSize.width),
            cap
        )
        return Self.namePad + measured + Self.nameGap + Self.size
    }

    /// Shows or hides the home-space name, taking the plate from
    /// rounded-square badge to full capsule (or back). The plate
    /// owns its own subview alpha and corner radius so the overlay
    /// drives only the panel width/frame. `animated` rides the
    /// caller's `NSAnimationContext` group.
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

    /// Animates the corner radius alongside a width change (a
    /// plain set inside `NSAnimationContext` doesn't drive the
    /// layer's implicit animation for a borderless panel).
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
