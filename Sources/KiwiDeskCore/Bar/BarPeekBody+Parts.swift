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

    /// The count as a bare number in the bar's group badge — the
    /// glyph's own badge, in its colours and face.
    func pill(_ count: Int, shelf: KiwiShelf) -> NSTextField {
        let pill = SpaceBarItemView.makeBadge()
        pill.stringValue = "\(count)"
        pill.font = shelf.badgeFont(
            ofSize: Metrics.countSize,
            emphasis: .bold
        )
        pill.textColor = NSColor(kiwiHex: shelf.groupBadgeTextColor)
        pill.layer?.backgroundColor =
            NSColor(kiwiHex: shelf.groupBadgeColor).cgColor
        pill.layer?.cornerRadius = Metrics.pillHeight / 2
        let text = ceil(pill.cell?.cellSize.width ?? 0)
        pill.frame.size = CGSize(
            width: max(Metrics.pillHeight, text + 2 * Metrics.pillPad),
            height: Metrics.pillHeight
        )
        return pill
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
