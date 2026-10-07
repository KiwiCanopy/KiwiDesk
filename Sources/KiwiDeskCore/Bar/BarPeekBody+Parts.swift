import AppKit

/// The peek body's parts: wrapped labels, the count pill and the
/// hairlines, and how each measures.
extension BarPeekBody {
    /// A wrapping label: a title wraps whole, never cut (#1946).
    static func label(
        _ text: String,
        _ font: NSFont,
        _ color: NSColor
    ) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = font
        field.textColor = color
        field.lineBreakMode = .byWordWrapping
        field.cell?.wraps = true
        field.cell?.truncatesLastVisibleLine = false
        field.drawsBackground = false
        field.setAccessibilityElement(false)
        return field
    }

    /// The width `field` reads at on one line.
    static func natural(_ field: NSTextField) -> CGFloat {
        let bound = CGRect(
            x: 0,
            y: 0,
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        return ceil(field.cell?.cellSize(forBounds: bound).width ?? 0)
    }

    /// The height `field` takes wrapped at `width`.
    static func height(of field: NSTextField, width: CGFloat) -> CGFloat {
        let bound = CGRect(
            x: 0,
            y: 0,
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )
        return ceil(field.cell?.cellSize(forBounds: bound).height ?? 0)
    }

    /// One line of `font`, where a header's icon and pill sit.
    static func lineHeight(_ font: NSFont?) -> CGFloat {
        guard let font else { return Metrics.pillHeight }
        return ceil(font.ascender - font.descender + font.leading)
    }

    /// The count in the bar's group badge: a window glyph, then the
    /// bare number — no noun, so no localized frame (owner ruling).
    func pill(_ count: Int, shelf: KiwiShelf) -> BarPeekPill {
        BarPeekPill(count, shelf: shelf)
    }

    /// A hairline at `y`, `x` in from the text's lead.
    func addRule(at y: CGFloat, x: CGFloat, width: CGFloat) {
        let rule = NSView(
            frame: CGRect(
                x: Metrics.padH + x,
                y: y,
                width: width,
                height: BarDivider.ruleThickness
            )
        )
        rule.wantsLayer = true
        rule.layer?.backgroundColor = ruleInk.cgColor
        addSubview(rule)
        rules.append(rule)
    }
}

/// The peek's count pill (#1946): `macwindow` in the header's step of
/// the badge ink, then the number in the full badge ink, on the fill.
@MainActor
final class BarPeekPill: NSView {
    let glyph = NSImageView()
    let number = SpaceBarItemView.makeBadge()

    init(_ count: Int, shelf: KiwiShelf) {
        typealias M = BarPeekBody.Metrics
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(false)
        let ink = NSColor(kiwiHex: shelf.groupBadgeTextColor)
        layer?.backgroundColor =
            NSColor(kiwiHex: shelf.groupBadgeColor).cgColor
        layer?.cornerRadius = M.pillHeight / 2
        // A ring in the row hairlines' ink, only where the badge
        // fill separates weakly from the plate (owner, #1946).
        layer?.borderWidth = shelf.peekPillNeedsRing ? M.pillRing : 0
        layer?.borderColor =
            BarDivider.color(textColor: shelf.itemColor).cgColor
        let font = shelf.badgeFont(ofSize: M.countSize, emphasis: .semibold)
        glyph.image = Self.glyphImage(for: font)
        glyph.contentTintColor = NSColor(
            kiwiHex: shelf.peekPillGlyphColor
        )
        glyph.setAccessibilityElement(false)
        number.stringValue = "\(count)"
        number.font = font
        number.textColor = ink
        number.layer?.backgroundColor = nil
        let text = ceil(number.cell?.cellSize.width ?? 0)
        let size = glyph.image?.size ?? .zero
        // The symbol's ink sits centred in its image, so centring
        // the image centres it on the number's figures (#1946).
        glyph.frame = CGRect(
            x: M.pillPad,
            y: (M.pillHeight - size.height) / 2,
            width: ceil(size.width),
            height: size.height
        )
        number.frame = CGRect(
            x: glyph.frame.maxX + M.pillGlyphGap,
            y: 0,
            width: text,
            height: M.pillHeight
        )
        addSubview(glyph)
        addSubview(number)
        frame.size = CGSize(
            width: max(M.pillHeight, number.frame.maxX + M.pillPad),
            height: M.pillHeight
        )
    }

    /// The point size at which `macwindow` draws as tall as the cap
    /// height of `font` — the count beside it — so a small-capped
    /// face never draws a glyph that dwarfs its number.
    static func glyphPointSize(for font: NSFont) -> CGFloat {
        font.capHeight / BarPeekBody.Metrics.pillGlyphInkPerPoint
    }

    static func glyphImage(for font: NSFont) -> NSImage? {
        NSImage(
            systemSymbolName: "macwindow",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            .init(pointSize: glyphPointSize(for: font), weight: .regular)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
