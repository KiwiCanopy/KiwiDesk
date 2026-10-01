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
    /// the clearance of a rounded leading end, where the icon
    /// sits — the title that follows it needs none at the
    /// trailing end (#1763, owner 2026-09-29) — the one reading
    /// the layout and the slot measurement share.
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
            last: last,
            outlined: look.activeIndicator == .outline
        )
        return ItemEnds(
            leading: edgePadding + ends.leading,
            trailing: edgePadding
        )
    }

    /// The group-count badge's side for a content side — the one
    /// derivation the layout and the slot measurement share.
    nonisolated static func badgeSide(contentSide: CGFloat) -> CGFloat {
        min(max(contentSide * 0.32, 9), 14)
    }

    /// The square the content is laid in: the shelf's content
    /// depth (#1682), never longer than the slot.
    var contentSide: CGFloat { contentSide(in: bounds.size) }

    /// Icon and name layout for horizontal bar (manual QA 2026-07-18,
    /// owner 2026-07-20).
    private func layoutHorizontal() {
        let placed = horizontalPlacement(in: bounds.size)
        label.isHidden = !placed.showsLabel
        var x = placed.x
        if !iconSlotHidden {
            layoutIconSlot(
                in: CGRect(
                    x: x,
                    y: (bounds.height - placed.side) / 2,
                    width: placed.side,
                    height: placed.side
                )
            )
            x += placed.side + placed.spacing
        }
        label.frame = CGRect(
            x: x,
            y: BarTextGlyph.originY(
                centredOn: bounds.midY,
                for: label,
                height: placed.text.height
            ),
            width: placed.text.width,
            height: placed.text.height
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
        guard let square = verticalIconSquare(in: bounds.size) else {
            return
        }
        layoutIconSlot(in: square)
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
