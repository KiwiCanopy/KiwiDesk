import AppKit

/// Slot layout implementation for `SpaceBarItemView`.
extension SpaceBarItemView {
    /// Cross-axis padding inside the slot.
    static let pad: CGFloat = 4

    /// Cell dimension for glyphs along the bar axis.
    var cellLength: CGFloat {
        let depth = horizontal ? bounds.height : bounds.width
        return max(depth - Self.pad * 2, 8)
    }

    /// Computes requested slot length for given app count and overflow badge.
    static func autoLength(
        appCount: Int,
        overflow: Int = 0,
        depth: CGFloat
    ) -> CGFloat {
        let cell = max(depth - pad * 2, 8)
        let slots = appCount + (overflow > 0 ? 1 : 0)
        let divider: CGFloat = slots > 0 ? pad + 1 + pad : 0
        return pad * 2 + cell + divider + CGFloat(slots) * cell
    }

    override func layout() {
        super.layout()
        let cell = cellLength
        if case .text = spaceGlyph {
            identifierLabel.font = .systemFont(
                ofSize: identifierFont
            )
        }
        // Restyle BEFORE placing: `place` measures each text
        // glyph to center it, and the glyph fonts are set in
        // `restyle`.
        restyle()
        var cursor = Self.pad
        place(identifierImage, at: cursor, cell: cell)
        place(identifierLabel, at: cursor, cell: cell)
        cursor += cell
        if !identifierDivider.isHidden {
            cursor += Self.pad
            let depth =
                horizontal ? bounds.height : bounds.width
            identifierDivider.frame = BarDivider.frame(
                at: cursor,
                depth: depth,
                cell: cell,
                horizontal: horizontal
            )
            cursor += 1 + Self.pad
        }
        for (index, view) in appViews.enumerated() {
            place(view, at: cursor, cell: cell)
            if index < badgeViews.count {
                layoutBadge(
                    badgeViews[index],
                    onCellAt: cursor,
                    cell: cell
                )
            }
            layoutStateBadges(
                at: index,
                onCellAt: cursor,
                cell: cell
            )
            cursor += cell
        }
        if overflow > 0 {
            layoutBadge(
                overflowBadge,
                onCellAt: cursor,
                cell: cell,
                centered: true
            )
            cursor += cell
        }
        layoutAccent()
    }

    /// Positions count badge on cell corner or centered for overflow.
    private func layoutBadge(
        _ badge: NSTextField,
        onCellAt offset: CGFloat,
        cell: CGFloat,
        centered: Bool = false
    ) {
        guard !badge.isHidden else { return }
        let base =
            centered
            ? cell * 0.8 : StateBadgeMetrics.side(cell: cell)
        badge.font = .systemFont(
            ofSize: base * (centered ? 0.5 : 0.72),
            weight: .bold
        )
        let textWidth = ceil(badge.cell?.cellSize.width ?? 0)
        let diameter = min(
            max(base, textWidth + 2),
            cell + 2
        )
        let cellRect =
            horizontal
            ? CGRect(
                x: offset,
                y: (bounds.height - cell) / 2,
                width: cell,
                height: cell
            )
            : CGRect(
                x: (bounds.width - cell) / 2,
                y: offset,
                width: cell,
                height: cell
            )
        let rect =
            centered
            ? CGRect(
                x: cellRect.midX - diameter / 2,
                y: cellRect.midY - diameter / 2,
                width: diameter,
                height: diameter
            )
            : CGRect(
                x: cellRect.maxX - diameter + 1,
                y: cellRect.minY - 1,
                width: diameter,
                height: diameter
            )
        badge.frame = backingAlignedRect(
            rect,
            options: .alignAllEdgesNearest
        )
        badge.layer?.cornerRadius = diameter / 2
    }

    /// Positions sticky and floating state badges on glyph cell (#414).
    private func layoutStateBadges(
        at index: Int,
        onCellAt offset: CGFloat,
        cell: CGFloat
    ) {
        let side = StateBadgeMetrics.side(cell: cell)
        let cellRect =
            horizontal
            ? CGRect(
                x: offset,
                y: (bounds.height - cell) / 2,
                width: cell,
                height: cell
            )
            : CGRect(
                x: (bounds.width - cell) / 2,
                y: offset,
                width: cell,
                height: cell
            )
        if index < stickyBadgeViews.count,
            !stickyBadgeViews[index].isHidden
        {
            let badge = stickyBadgeViews[index]
            badge.frame = backingAlignedRect(
                CGRect(
                    x: cellRect.minX - 1,
                    y: cellRect.minY - 1,
                    width: side,
                    height: side
                ),
                options: .alignAllEdgesNearest
            )
            badge.needsLayout = true
        }
        if index < floatingBadgeViews.count,
            !floatingBadgeViews[index].isHidden
        {
            let badge = floatingBadgeViews[index]
            badge.frame = backingAlignedRect(
                CGRect(
                    x: cellRect.minX - 1,
                    y: cellRect.maxY - side + 1,
                    width: side,
                    height: side
                ),
                options: .alignAllEdgesNearest
            )
            badge.needsLayout = true
        }
    }

    private func place(
        _ view: NSView,
        at offset: CGFloat,
        cell: CGFloat
    ) {
        var rect =
            horizontal
            ? CGRect(
                x: offset,
                y: (bounds.height - cell) / 2,
                width: cell,
                height: cell
            )
            : CGRect(
                x: (bounds.width - cell) / 2,
                y: offset,
                width: cell,
                height: cell
            )
        // Center text glyph vertically (`AppBarItemView+GlyphSlot`).
        if let field = view as? NSTextField {
            let height = ceil(
                field.cell?.cellSize.height ?? 0
            )
            if height > 0, height < rect.height {
                rect.origin.y +=
                    ((rect.height - height) / 2).rounded()
                rect.size.height = height
            }
        }
        view.frame = backingAlignedRect(
            rect,
            options: .alignAllEdgesNearest
        )
    }

    private func layoutAccent() {
        switch style.activeIndicator {
        case .outline:
            // Boxed hugs the box; unboxed insets (`BarAccent.capsuleInset`,
            // QA 2026-07-19).
            accent.frame =
                style.hasBox
                ? bounds
                : bounds.insetBy(
                    dx: BarAccent.capsuleInset,
                    dy: BarAccent.capsuleInset
                )
        case .edgeMark:
            // Positions edge indicator on window-facing side of slot.
            let mark: CGFloat = 3
            switch style.edge {
            case .top:
                accent.frame = CGRect(
                    x: 0,
                    y: bounds.height - mark,
                    width: bounds.width,
                    height: mark
                )
            case .bottom:
                accent.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: bounds.width,
                    height: mark
                )
            case .left:
                accent.frame = CGRect(
                    x: bounds.width - mark,
                    y: 0,
                    width: mark,
                    height: bounds.height
                )
            case .right:
                accent.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: mark,
                    height: bounds.height
                )
            }
        case .gap:
            accent.frame = .zero
        }
    }
}
