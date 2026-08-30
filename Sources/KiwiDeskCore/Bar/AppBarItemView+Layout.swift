import AppKit

/// Slot layout: icon and name centered as one group, scaled with thickness.
extension AppBarItemView {
    override func layout() {
        super.layout()
        applyCornerRadius()
        layoutAccent()
        if horizontal {
            layoutHorizontal()
        } else {
            layoutVertical()
        }
        layoutBadge()
    }

    /// Group-count badge layout (QA 2026-07-19, owner 2026-07-20, #411).
    private func layoutBadge() {
        guard !badge.isHidden else { return }
        let baseHeight = min(
            max(
                min(bounds.width, bounds.height) * 0.32,
                9
            ),
            14
        )
        badge.font = .systemFont(
            ofSize: baseHeight * 0.9,
            weight: .bold
        )
        let textWidth = ceil(badge.cell?.cellSize.width ?? 0)
        let diameter = max(baseHeight, textWidth + 2)
        let x: CGFloat
        let y: CGFloat
        if !label.isHidden, label.frame.width > 0 {
            x = label.frame.maxX + 2
            y = label.frame.minY - diameter / 3
        } else {
            let box =
                !glyphLabel.isHidden
                ? glyphLabel.frame
                : (!iconView.isHidden ? iconView.frame : bounds)
            x = box.maxX - diameter / 2
            y = box.minY - diameter / 2
        }
        let corner = style.resolvedCornerRadius(
            forThickness: crossThickness
        )
        let inset =
            max(0, corner - diameter / 2)
            * (1 - 1 / 2.0.squareRoot())
        let maxX = max(0, bounds.width - diameter - inset)
        let maxY = max(0, bounds.height - diameter)
        badge.frame = CGRect(
            x: min(max(x, 0), maxX),
            y: min(max(y, inset), maxY),
            width: diameter,
            height: diameter
        )
        badge.layer?.cornerRadius = diameter / 2
    }

    nonisolated static let contentPadding: CGFloat = 4
    /// Slot leading/trailing inset (manual QA 2026-07-18).
    nonisolated static let edgePadding: CGFloat = 6

    private var effectiveFontSize: CGFloat {
        style.resolvedFontSize(
            forThickness: horizontal
                ? bounds.height : bounds.width
        )
    }

    /// Icon and name layout for horizontal bar (manual QA 2026-07-18,
    /// owner 2026-07-20).
    private func layoutHorizontal() {
        let pad = Self.contentPadding
        let edge = Self.edgePadding
        let font = NSFont.systemFont(ofSize: effectiveFontSize)
        label.font = font
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.stringValue = text
        let side =
            iconSlotHidden
            ? 0
            : max(
                min(bounds.height, bounds.width) - pad * 2,
                0
            )
        let showText = style.content.showsText
        var textSize =
            showText
            ? (label.cell?.cellSize ?? .zero)
            : .zero
        textSize.width = ceil(textSize.width)
        textSize.height = ceil(textSize.height)
        var spacing: CGFloat =
            side > 0 && showText ? pad / 2 : 0
        let badgeReserve: CGFloat =
            count >= 2 && showText
            ? min(max(min(bounds.height, bounds.width) * 0.32, 9), 14)
                + pad
            : 0
        textSize.width = min(
            textSize.width,
            bounds.width - side - spacing - edge * 2 - badgeReserve
        )
        if textSize.width < 8 {
            textSize.width = 0
            spacing = 0
        }
        label.isHidden = !showText || textSize.width == 0
        let badgeExtent: CGFloat =
            badgeReserve > 0 && textSize.width > 0
            ? badgeReserve - pad + 2
            : 0
        var x = max(
            (bounds.width - side - spacing - textSize.width
                - badgeExtent) / 2,
            showText ? edge : pad
        )
        if !iconSlotHidden {
            layoutIconSlot(
                in: CGRect(
                    x: x,
                    y: (bounds.height - side) / 2,
                    width: side,
                    height: side
                )
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

    /// Vertical bar icon-only layout (QA 2026-07-19; tested in
    /// `AppBarGlyphLayoutTests.verticalReuseHidesLabel`).
    private func layoutVertical() {
        label.isHidden = true
        let pad = Self.contentPadding
        let side =
            iconSlotHidden
            ? 0
            : max(
                min(bounds.width, bounds.height) - pad * 2,
                0
            )
        guard side > 0 else { return }
        layoutIconSlot(
            in: CGRect(
                x: (bounds.width - side) / 2,
                y: max((bounds.height - side) / 2, pad),
                width: side,
                height: side
            )
        )
    }

    private func layoutAccent() {
        guard !accent.isHidden else { return }
        switch accentMode {
        case .outline: layoutRing()
        case .edgeMark: layoutEdgeMark()
        case .none: break
        }
    }

    /// Outline selection ring (ui-designer 2026-07-14, owner 2026-07-20).
    private func layoutRing() {
        if style.hasBox {
            accent.frame = bounds
            accent.layer?.cornerRadius =
                style.resolvedCornerRadius(
                    forThickness: crossThickness
                )
        } else {
            let inset = BarAccent.capsuleInset
            accent.frame = bounds.insetBy(dx: inset, dy: inset)
            accent.layer?.cornerRadius = max(
                0,
                style.resolvedCornerRadius(
                    forThickness: crossThickness
                ) - inset
            )
        }
    }

    /// Edge mark layout (owner call 2026-07-20).
    private func layoutEdgeMark() {
        accent.layer?.cornerRadius = 0
        let thickness: CGFloat = 3
        switch edge {
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
}
