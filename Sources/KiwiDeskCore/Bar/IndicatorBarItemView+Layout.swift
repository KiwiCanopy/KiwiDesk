import AppKit

/// Slot layout: icon and name centered as one group, font
/// scaled with the bar thickness, name-only truncation.
extension IndicatorBarItemView {
    override func layout() {
        super.layout()
        layoutAccent()
        if horizontal {
            layoutHorizontal()
        } else {
            layoutVertical()
        }
        layoutBadge()
    }

    /// The group-count badge hugs the slot's top-right
    /// corner (flipped coordinates): a filled circle that
    /// grows into a larger circle for multi-digit counts.
    private func layoutBadge() {
        guard !badge.isHidden else { return }
        let baseHeight = min(
            max(
                min(bounds.width, bounds.height) * 0.38,
                10
            ),
            14
        )
        badge.font = .systemFont(
            ofSize: baseHeight * 0.9,
            weight: .bold
        )
        // Ensure text fits centered; width must equal height
        // to maintain a proper circle. We add minimal horizontal
        // padding to keep the badge tight around the text.
        let textWidth = ceil(badge.cell?.cellSize.width ?? 0)
        let diameter = max(baseHeight, textWidth + 2)
        let cornerPadding: CGFloat = 3
        badge.frame = CGRect(
            x: bounds.width - diameter - cornerPadding,
            y: cornerPadding,
            width: diameter,
            height: diameter
        )
        badge.layer?.cornerRadius = diameter / 2
    }

    /// Shared with the overlay's natural-width measurement.
    nonisolated static let contentPadding: CGFloat = 4

    /// `bar_font_size` 0 = auto: scale with the bar's cross
    /// dimension (its thickness), so a fat bar gets readable
    /// text and a slim one stays inside its strip.
    private var effectiveFontSize: CGFloat {
        if params.bar.fontSize > 0 {
            return params.bar.fontSize
        }
        return Self.autoFontSize(
            forThickness: horizontal
                ? bounds.height : bounds.width
        )
    }

    nonisolated static func autoFontSize(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        min(max(thickness * 0.42, 9), 28)
    }

    /// Icon and name sit centered in the slot as one group;
    /// when space runs out, only the name shrinks — the icon
    /// always survives.
    private func layoutHorizontal() {
        let pad = Self.contentPadding
        let font = NSFont.systemFont(ofSize: effectiveFontSize)
        label.font = font
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.stringValue = name
        let side =
            iconView.isHidden
            ? 0
            : max(
                min(bounds.height, bounds.width) - pad * 2,
                0
            )
        // The cell itself knows how much room the name needs;
        // measuring the raw string undershoots the cell's own
        // padding and truncates names that would have fit.
        var textSize =
            params.bar.content == .icon
            ? .zero
            : (label.cell?.cellSize ?? .zero)
        textSize.width = ceil(textSize.width)
        textSize.height = ceil(textSize.height)
        let showText = params.bar.content != .icon
        var spacing: CGFloat =
            side > 0 && showText ? pad : 0
        textSize.width = min(
            textSize.width,
            bounds.width - side - spacing - pad * 2
        )
        if textSize.width < 8 {
            textSize.width = 0
            spacing = 0
        }
        label.isHidden = !showText || textSize.width == 0
        var x = max(
            (bounds.width - side - spacing - textSize.width)
                / 2,
            pad
        )
        if !iconView.isHidden {
            iconView.frame = CGRect(
                x: x,
                y: (bounds.height - side) / 2,
                width: side,
                height: side
            )
            x += side + spacing
        }
        label.frame = CGRect(
            x: x,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
    }

    /// Vertical bars: icon on top, letters stacked below,
    /// the whole group vertically centered in the slot.
    private func layoutVertical() {
        let pad = Self.contentPadding
        let font = NSFont.systemFont(ofSize: effectiveFontSize)
        label.font = font
        let side =
            iconView.isHidden
            ? 0
            : max(
                min(bounds.width, bounds.height) - pad * 2,
                0
            )
        let spacing: CGFloat = side > 0 ? pad : 0
        let lineHeight = font.pointSize * 1.3
        let available =
            bounds.height - side - spacing - pad * 2
        let maxLines = Int(available / max(lineHeight, 1))
        let showText =
            params.bar.content != .icon && maxLines >= 1
        label.isHidden = !showText
        let lines =
            showText ? min(name.count, maxLines) : 0
        let textHeight = CGFloat(lines) * lineHeight
        if showText {
            label.usesSingleLineMode = false
            label.maximumNumberOfLines = 0
            label.lineBreakMode = .byClipping
            label.stringValue = Self.stacked(
                name,
                limit: maxLines
            )
        }
        var top = max(
            (bounds.height - side - spacing - textHeight)
                / 2,
            pad
        )
        if !iconView.isHidden {
            iconView.frame = CGRect(
                x: (bounds.width - side) / 2,
                y: top,
                width: side,
                height: side
            )
            top += side + spacing
        }
        label.frame = CGRect(
            x: 0,
            y: top,
            width: bounds.width,
            height: textHeight
        )
    }

    private func layoutAccent() {
        guard !accent.isHidden else { return }
        let thickness: CGFloat = 3
        // The accent hugs the window-facing edge of the slot
        // (flipped coordinates: y grows downward).
        switch params.resolvedBarPosition {
        case .top:
            accent.frame = CGRect(
                x: 0,
                y: bounds.height - thickness,
                width: bounds.width,
                height: thickness
            )
        case .bottom:
            accent.frame = CGRect(
                x: 0,
                y: 0,
                width: bounds.width,
                height: thickness
            )
        case .left:
            accent.frame = CGRect(
                x: bounds.width - thickness,
                y: 0,
                width: thickness,
                height: bounds.height
            )
        case .right:
            accent.frame = CGRect(
                x: 0,
                y: 0,
                width: thickness,
                height: bounds.height
            )
        }
    }

    /// "Safari" -> "S\na\nf\n…" for narrow vertical bars.
    nonisolated static func stacked(
        _ name: String,
        limit: Int
    ) -> String {
        guard limit > 0 else { return "" }
        var letters = name.map(String.init)
        if letters.count > limit {
            letters = Array(letters.prefix(limit - 1)) + ["…"]
        }
        return letters.joined(separator: "\n")
    }
}
