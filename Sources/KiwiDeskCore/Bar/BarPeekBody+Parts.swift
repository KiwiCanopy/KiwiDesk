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

/// The peek's count pill (#1946): `macwindow` then the number, both
/// in the badge ink, on the badge fill.
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
        // A ring in the row hairlines' ink, so the pill holds its
        // edge on a ground near the badge fill (owner, device).
        layer?.borderWidth = M.pillRing
        layer?.borderColor =
            BarDivider.color(textColor: shelf.itemColor).cgColor
        glyph.image = NSImage(
            systemSymbolName: "macwindow",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            .init(pointSize: M.pillGlyphSize, weight: .semibold)
        )
        glyph.contentTintColor = ink
        glyph.setAccessibilityElement(false)
        number.stringValue = "\(count)"
        number.font = shelf.badgeFont(ofSize: M.countSize, emphasis: .semibold)
        number.textColor = ink
        number.layer?.backgroundColor = nil
        let text = ceil(number.cell?.cellSize.width ?? 0)
        let glyphWidth = ceil(glyph.image?.size.width ?? M.pillGlyphSize)
        glyph.frame = CGRect(
            x: M.pillPad,
            y: (M.pillHeight - M.pillGlyphSize) / 2,
            width: glyphWidth,
            height: M.pillGlyphSize
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

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
