import AppKit

/// The peek body's parts: wrapped labels and the hairlines, and
/// how each measures.
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

    /// One line of `font`, where a header's icon sits.
    static func lineHeight(_ font: NSFont?) -> CGFloat {
        guard let font else { return Metrics.iconSide }
        return ceil(font.ascender - font.descender + font.leading)
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
