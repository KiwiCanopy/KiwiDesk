import AppKit

/// How a home space is shown inside the pill (#421): its
/// configured Space Bar identifier — an SF Symbol or an
/// emoji/character — or the bare id/name as fallback. The same
/// identity the Space Bar shows, so the pill and a bar tile read
/// as the same space.
public enum SpaceMark: Equatable {
    case symbol(String)
    case text(String)
}

/// The sticky mark's rounded plate (#414/#421): the sticky glyph
/// pinned in the rightmost square, and a home-space name to its
/// left, hidden until the mark flashes into a pill. Lays its two
/// subviews out from the live bounds in `layout()` — called on
/// every step of the plate's width animation — so the glyph holds
/// its screen position while the name stretches into view.
@MainActor
final class StickyMarkPlate: NSVisualEffectView {
    /// Collapsed mark square; the glyph always occupies the
    /// rightmost square of this side.
    static let size: CGFloat = 20
    /// Padding left of the name, and the gap between name and
    /// glyph.
    static let namePad: CGFloat = 8
    static let nameGap: CGFloat = 4
    /// Sanity ceiling on pill width; the caller also clamps to the
    /// window so the pill never overruns its own window edge, and
    /// only a genuinely long space name tail-truncates.
    static let maxWidth: CGFloat = 360
    /// Collapsed reads as a rounded square badge, expanded as a
    /// full capsule — the shape change is the "shows more" signal.
    static let collapsedRadius: CGFloat = size / 4
    static let expandedRadius: CGFloat = size / 2

    let symbol = NSImageView()
    let name = NSTextField(labelWithString: "")
    /// The colored disc behind the glyph when a mark color is set
    /// (#429): the on-window twin of the Space Bar state badge, so
    /// the mark and the badge read as the same filled mark. Hidden
    /// on Automatic — the mark is then the bare neutral glyph on
    /// glass (today's look).
    let roundel = NSView()
    /// Roundel diameter inside the 20pt glyph square — a touch
    /// smaller so the glass frames it.
    static let roundelSize: CGFloat = 15

    /// The resolved mark tint (#429): the sticky color, or the
    /// adaptive `.labelColor` when "Automatic" (empty hex). Owns
    /// the pill's home-space name (and its inline symbol); the
    /// glyph itself sits on the roundel in an auto-contrast color.
    private var markColor: NSColor = .labelColor

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

        roundel.wantsLayer = true
        roundel.layer?.cornerRadius = Self.roundelSize / 2
        roundel.isHidden = true

        addSubview(name)
        addSubview(roundel)
        addSubview(symbol)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Applies the sticky mark tint (#429). Automatic (empty hex):
    /// the bare neutral glyph on glass — roundel hidden, glyph and
    /// pill name in the adaptive `.labelColor` (today's look). A
    /// chosen color: a filled roundel behind the glyph, the glyph
    /// auto-contrasted on it, and the pill name in the mark color.
    /// The pill name re-tints on the next `prepare`.
    func setMarkColor(_ hex: String) {
        if hex.isEmpty {
            markColor = .labelColor
            roundel.isHidden = true
            symbol.contentTintColor = .labelColor
        } else {
            let fill = NSColor(kiwiHex: hex)
            markColor = fill
            roundel.isHidden = false
            roundel.layer?.backgroundColor = fill.cgColor
            symbol.contentTintColor = fill.contrastingGlyph
        }
        name.textColor = markColor
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        symbol.frame = CGRect(
            x: w - Self.size,
            y: 0,
            width: Self.size,
            height: Self.size
        )
        // The roundel is centered in the same rightmost square as
        // the glyph, so it stays pinned to the window corner while
        // the pill grows leftward.
        let inset = (Self.size - Self.roundelSize) / 2
        roundel.frame = CGRect(
            x: w - Self.size + inset,
            y: inset,
            width: Self.roundelSize,
            height: Self.roundelSize
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

    /// Builds the pill content by substituting `mark` into the
    /// localized `format` at its `%1$@` slot — an SF Symbol renders
    /// as an inline image, an emoji/name as text — sets it on the
    /// label, and returns the expanded pill width (capped so a
    /// genuinely long name truncates rather than sprawls; +1pt so
    /// the last glyph never clips under `byTruncatingTail`).
    func prepare(format: String, mark: SpaceMark) -> CGFloat {
        let content = attributedContent(format: format, mark: mark)
        name.attributedStringValue = content
        let textWidth = ceil(content.size().width) + 1
        let cap =
            Self.maxWidth - Self.namePad - Self.nameGap - Self.size
        let measured = min(textWidth, cap)
        return Self.namePad + measured + Self.nameGap + Self.size
    }

    private var nameFont: NSFont {
        name.font ?? .systemFont(ofSize: 11, weight: .semibold)
    }

    private func attributedContent(
        format: String,
        mark: SpaceMark
    ) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: markColor,
        ]
        // Split on the positional slot so the substituted mark
        // keeps whatever order the translation puts it in.
        let parts = format.components(separatedBy: "%1$@")
        let out = NSMutableAttributedString(
            string: parts.first ?? "",
            attributes: attrs
        )
        switch mark {
        case .text(let value):
            out.append(
                NSAttributedString(string: value, attributes: attrs)
            )
        case .symbol(let symbolName):
            out.append(symbolRun(symbolName, attrs: attrs))
        }
        if parts.count > 1 {
            out.append(
                NSAttributedString(
                    string: parts[1],
                    attributes: attrs
                )
            )
        }
        return out
    }

    /// The space's SF Symbol as an inline, baseline-centered image
    /// tinted to match the text; falls back to the bare symbol name
    /// if the symbol can't be realized.
    private func symbolRun(
        _ symbolName: String,
        attrs: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let config = NSImage.SymbolConfiguration(
            pointSize: nameFont.pointSize,
            weight: .semibold
        )
        .applying(
            NSImage.SymbolConfiguration(paletteColors: [markColor])
        )
        guard
            let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            )?.withSymbolConfiguration(config)
        else {
            return NSAttributedString(
                string: symbolName,
                attributes: attrs
            )
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        let mid = (nameFont.capHeight - image.size.height) / 2
        attachment.bounds = CGRect(
            x: 0,
            y: mid,
            width: image.size.width,
            height: image.size.height
        )
        return NSAttributedString(attachment: attachment)
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
