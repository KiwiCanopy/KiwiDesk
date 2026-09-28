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
        let baseHeight = Self.badgeSide(contentSide: contentSide)
        badge.font = style.shelf.badgeFont(
            ofSize: baseHeight * 0.9,
            emphasis: .bold
        )
        let textWidth = ceil(badge.cell?.cellSize.width ?? 0)
        let diameter = max(baseHeight, textWidth + 2)
        let x: CGFloat
        let y: CGFloat
        if !label.isHidden, label.frame.width > 0 {
            x = label.frame.maxX + 2
            y = label.frame.minY - diameter / 3
        } else {
            // The glyph's frame carries the cell's padding; the
            // badge hangs on the ink (#1543).
            let box =
                !glyphLabel.isHidden
                ? glyphInkFrame
                : (!iconView.isHidden ? iconView.frame : bounds)
            x = box.maxX - diameter / 2
            y = box.minY - diameter / 2
        }
        let corner = style.resolvedCornerRadius(
            forThickness: crossThickness
        )
        let inset = KiwiShelf.cornerCut(
            radius: corner - diameter / 2
        )
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

    /// A horizontal slot's leading and trailing insets on a strip
    /// `depth` deep, at its place in the run: `edgePadding` plus
    /// the clearance of each end it draws rounded (#1763) — the one
    /// reading the layout and the slot measurement share.
    nonisolated static func endPadding(
        _ look: AppBarLook,
        depth: CGFloat,
        first: Bool,
        last: Bool
    ) -> ItemEnds {
        let side = max(
            look.contentDepth(forDepth: depth) - contentPadding * 2,
            0
        )
        let ends = look.shelf.itemEnds(
            clearance: KiwiShelf.endClearance(
                radius: look.resolvedCornerRadius(forThickness: depth),
                crossOffset: (depth - side) / 2
            ),
            first: first,
            last: last
        )
        return ItemEnds(
            leading: edgePadding + ends.leading,
            trailing: edgePadding + ends.trailing
        )
    }

    /// The group-count badge's side for a content side — the one
    /// derivation the layout and the slot measurement share.
    nonisolated static func badgeSide(contentSide: CGFloat) -> CGFloat {
        min(max(contentSide * 0.32, 9), 14)
    }

    /// The square the content is laid in: the shelf's content
    /// depth (#1682), never longer than the slot.
    var contentSide: CGFloat {
        min(
            style.contentDepth(forDepth: crossThickness),
            horizontal ? bounds.width : bounds.height
        )
    }

    private var effectiveFontSize: CGFloat {
        style.resolvedFontSize(forDepth: crossThickness)
    }

    /// Icon and name layout for horizontal bar (manual QA 2026-07-18,
    /// owner 2026-07-20).
    private func layoutHorizontal() {
        let pad = Self.contentPadding
        let edge = Self.endPadding(
            style,
            depth: crossThickness,
            first: isFirstInRun,
            last: isLastInRun
        )
        let font = style.shelf.textFont(ofSize: effectiveFontSize)
        label.font = font
        // Not `usesSingleLineMode`: it draws a tall face above its
        // own ascent, clipping the title (#1707).
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.stringValue = text
        let side =
            iconSlotHidden ? 0 : max(contentSide - pad * 2, 0)
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
            ? Self.badgeSide(contentSide: contentSide) + pad
            : 0
        textSize.width = min(
            textSize.width,
            bounds.width - side - spacing - edge.total - badgeReserve
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
        // Centred between the two ends' insets, which differ where
        // only one end is drawn rounded (#1763).
        var x = max(
            (bounds.width - side - spacing - textSize.width
                - badgeExtent + edge.leading - edge.trailing) / 2,
            showText ? edge.leading : pad
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
            y: BarTextGlyph.originY(
                capsCentredOn: bounds.midY,
                for: label,
                height: textSize.height
            ),
            width: textSize.width,
            height: textSize.height
        )
    }

    /// Vertical bar icon-only layout (QA 2026-07-19). This pass
    /// hides the label ITSELF, and must: item views are reused
    /// across renders, so one that laid out horizontally arrives
    /// still showing a stale title — the hide looked redundant
    /// from every horizontal fixture and was deleted once, a real
    /// defect for one commit
    /// (`AppBarGlyphLayoutTests.verticalReuseHidesLabel`). Hidden
    /// BEFORE the `side` guard, which can return early.
    private func layoutVertical() {
        label.isHidden = true
        let pad = Self.contentPadding
        let side =
            iconSlotHidden ? 0 : max(contentSide - pad * 2, 0)
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
        let thickness = style.edgeMarkThickness
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
