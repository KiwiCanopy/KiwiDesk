import AppKit

/// Slot layout implementation for `SpaceBarItemView`.
extension SpaceBarItemView {
    /// Cross-axis padding inside the slot.
    static let pad: CGFloat = 4

    /// The item's depth across the shelf.
    var depth: CGFloat { horizontal ? bounds.height : bounds.width }

    /// The depth this item's content is sized to (#1682).
    var contentDepth: CGFloat { style.contentDepth(forDepth: depth) }

    /// Cell dimension for glyphs along the bar axis.
    var cellLength: CGFloat { Self.cell(contentDepth: contentDepth) }

    /// A glyph cell's side for a content depth — the one
    /// derivation the items and the front-app segment share.
    static func cell(contentDepth: CGFloat) -> CGFloat {
        max(contentDepth - pad * 2, 8)
    }

    /// Computes requested slot length for given app count and overflow badge.
    /// `glyphGap` is the style's `resolvedGlyphGap`, taken with
    /// no default so a caller cannot measure without it (#1689);
    /// `contentDepth` is the shelf's for the strip (#1682).
    static func autoLength(
        appCount: Int,
        overflow: Int = 0,
        contentDepth: CGFloat,
        glyphGap: CGFloat
    ) -> CGFloat {
        let cell = cell(contentDepth: contentDepth)
        let slots = appCount + (overflow > 0 ? 1 : 0)
        let divider: CGFloat = slots > 0 ? pad + 1 + pad : 0
        let gaps = CGFloat(max(slots - 1, 0)) * glyphGap
        return pad * 2 + cell + divider + CGFloat(slots) * cell + gaps
    }

    override func layout() {
        super.layout()
        let cell = cellLength
        if case .text = spaceGlyph {
            identifierLabel.font = style.shelf.textFont(
                ofSize: identifierFont
            )
        }
        // Restyle BEFORE placing: `place` measures each text
        // glyph to center it, and the glyph fonts are set in
        // `restyle`.
        restyle()
        var cursor = Self.pad
        place(identifierImage, at: cursor, cell: cell)
        place(
            identifierLabel,
            at: cursor,
            cell: cell,
            slack: Self.pad
        )
        layoutHeldBadge(onCellAt: cursor, cell: cell)
        if collapse != nil {
            // The held asterisk owns the top corner (#1507).
            layoutBadge(
                overflowBadge,
                onCellAt: cursor,
                cell: cell,
                lowerCorner: held != nil
            )
        }
        cursor += cell
        if !identifierDivider.isHidden {
            cursor += Self.pad
            // An in-item rule is content: centred on the full
            // depth, as long as the content allows (#1682).
            identifierDivider.frame = BarDivider.frame(
                at: cursor,
                depth: depth,
                horizontal: horizontal,
                lengthShare: BarDivider.ruleLengthShare
                    * contentDepth / max(depth, 1)
            )
            cursor += 1 + Self.pad
        }
        let glyphGap = style.resolvedGlyphGap
        for (index, view) in appViews.enumerated() {
            if index > 0 { cursor += glyphGap }
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
        if collapse == nil, overflow > 0 {
            if !appViews.isEmpty { cursor += glyphGap }
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
        centered: Bool = false,
        lowerCorner: Bool = false
    ) {
        guard !badge.isHidden else { return }
        let base =
            centered
            ? cell * 0.8 : StateBadgeMetrics.side(cell: cell)
        badge.font = style.shelf.badgeFont(
            ofSize: base * (centered ? 0.5 : 0.72),
            emphasis: .bold
        )
        let textWidth = ceil(badge.cell?.cellSize.width ?? 0)
        // Below the held asterisk the disc keeps clear of it.
        let ceiling =
            lowerCorner
            ? max(cell - StateBadgeMetrics.side(cell: cell), base)
            : cell + 2
        let diameter = min(max(base, textWidth + 2), ceiling)
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
                y: lowerCorner
                    ? cellRect.maxY - diameter + 1 : cellRect.minY - 1,
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

    /// `slack` is how far a text glyph's ink may reach past the
    /// cell on a side before its font is scaled (`BarTextGlyph`).
    private func place(
        _ view: NSView,
        at offset: CGFloat,
        cell: CGFloat,
        slack: CGFloat = 0
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
        if let field = view as? NSTextField {
            rect = BarTextGlyph.frame(
                for: field,
                in: rect,
                slack: slack
            )
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
            let mark = style.edgeMarkThickness
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
        }
        applySheen()
    }
}
