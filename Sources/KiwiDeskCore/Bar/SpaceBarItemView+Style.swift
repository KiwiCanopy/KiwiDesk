import AppKit

/// State-dependent styling for SpaceBarItemView (#293).
extension SpaceBarItemView {
    func restyle() {
        layer?.masksToBounds = false
        layer?.cornerRadius = cornerRadius
        layer?.maskedCorners = maskedCorners
        hoverFill.frame = bounds
        let glassHover = BarHoverFill.paint(
            hoverFill,
            showsHover: showsHover,
            hex: style.hoverFillColor,
            shelf: style.shelf,
            edge: style.edge,
            cornerRadius: cornerRadius,
            corners: maskedCorners
        )
        layer?.backgroundColor = (glassHover ? .clear : fillColor).cgColor
        accentClip.frame = bounds
        aboveOutline.frame = bounds
        accentClip.layer?.masksToBounds = true
        accentClip.layer?.cornerRadius = cornerRadius
        accentClip.layer?.maskedCorners = maskedCorners
        boxBorder.frame = bounds
        ShelfBorder.paint(
            boxBorder,
            shelf: style.shelf,
            surface: .box,
            under: drawnIndicator,
            cornerRadius: cornerRadius,
            sheen: style.sheen
        )
        styleIdentifier()
        styleApps()
        styleBadges()
        styleMarker()
        styleDivider()
        styleAccent()
    }

    /// The border, the outline and what draws over it: seated
    /// above a hosting glass's rim (#2595).
    var strokes: [GlassBoxRider] { [boxBorder, accentClip, aboveOutline] }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        GlassBox.seatStrokes(strokes, of: self)
        BarHoverFill.seat(hoverFill, below: boxBorder, in: self)
    }

    /// Structural divider between identifier and app glyphs (QA 2026-07-19).
    private func styleDivider() {
        identifierDivider.isHidden = apps.isEmpty
        identifierDivider.layer?.backgroundColor =
            BarDivider.color(textColor: style.itemColor)
            .cgColor
    }

    /// Alpha for untinted elements (QA 2026-07-19). The layer
    /// item reads full-strength on this channel as on the ink
    /// (#1169): an emoji icon takes no tint, so this is the one
    /// channel that could dim it.
    var untintedAlpha: CGFloat {
        isActive || isHovered || isDragHovered || space == nil
            ? 1 : style.dimFactor
    }

    /// Styles count and overflow badges (#293).
    private func styleBadges() {
        for (index, app) in apps.enumerated() {
            guard index < badgeViews.count else { break }
            let badge = badgeViews[index]
            badge.isHidden = app.count < 2
            badge.stringValue = "\(app.count)"
            applyBadge(
                badge,
                appFocused: app.focused,
                lit: glyphIsHovered(index),
                count: true
            )
        }
        overflowBadge.isHidden =
            (collapse?.windows ?? after.windows.count) < 1
        // A collapsed count is the whole count, not "more".
        overflowBadge.stringValue =
            collapse?.discText ?? "+\(after.windows.count)"
        applyBadge(
            overflowBadge,
            appFocused: after.holdsFocus,
            lit: overflowTarget.map { $0 === hoveredTarget } ?? false,
            count: false
        )
        leadingBadge.isHidden = collapse != nil || before.windows.isEmpty
        leadingBadge.stringValue = "+\(before.windows.count)"
        applyBadge(
            leadingBadge,
            appFocused: before.holdsFocus,
            lit: leadingTarget.map { $0 === hoveredTarget } ?? false,
            count: false
        )
        styleStateBadges()
    }

    /// Styles sticky / floating corner state badges (#414).
    private func styleStateBadges() {
        for (index, app) in apps.enumerated() {
            if index < stickyBadgeViews.count,
                let badge = stickyBadgeViews[index]
            {
                applyStateBadge(
                    badge,
                    shown: style.stickyBadge && app.sticky,
                    markHex: stateMarkColors.sticky,
                    appFocused: app.focused
                )
            }
            if index < floatingBadgeViews.count,
                let badge = floatingBadgeViews[index]
            {
                applyStateBadge(
                    badge,
                    shown: style.stickyBadge && app.floating,
                    markHex: stateMarkColors.floating,
                    appFocused: app.focused
                )
            }
        }
    }

    /// State badge fill and contrast glyph (#429).
    private func applyStateBadge(
        _ badge: StateBadgeView,
        shown: Bool,
        markHex: String,
        appFocused: Bool
    ) {
        badge.isHidden = !shown
        let fill = NSColor.mark(
            hex: markHex,
            fallback: NSColor(kiwiHex: style.groupBadgeColor)
        )
        badge.layer?.backgroundColor = fill.cgColor
        badge.symbol.contentTintColor = fill.contrastingGlyph
        badge.alphaValue = untintedAppAlpha(focused: appFocused)
    }

    /// Group badge styling with 3-tier alpha ladder
    /// (#470, #955, owner 2026-07-20); a `count` badge takes the
    /// ladder's count tier (#2650).
    private func applyBadge(
        _ badge: NSTextField,
        appFocused: Bool,
        lit: Bool,
        count: Bool
    ) {
        badge.layer?.backgroundColor =
            NSColor(kiwiHex: style.groupBadgeColor).cgColor
        badge.textColor =
            NSColor(kiwiHex: style.groupBadgeTextColor)
        badge.alphaValue =
            lit ? 1 : untintedAppAlpha(focused: appFocused, count: count)
    }

    var cornerRadius: CGFloat {
        Self.boxRadius(look: style, depth: depth, size: bounds.size)
    }

    /// A Space item box's radius — the one derivation its layer
    /// and its glass read: from the full `depth`, as every item's,
    /// so a glyphless item shorter than the depth under item
    /// padding rounds like its neighbours; never past half the
    /// box's shorter side (#1682).
    static func boxRadius(
        look: SpaceBarLook,
        depth: CGFloat,
        size: CGSize
    ) -> CGFloat {
        min(
            look.resolvedCornerRadius(forThickness: depth),
            min(size.width, size.height) / 2
        )
    }

    /// The corners this item rounds (`ItemCornerMask`, #1763).
    private var maskedCorners: CACornerMask {
        ItemCornerMask.mask(
            shelf: style.shelf,
            first: isFirstInRun,
            last: isLastInRun,
            outlined: style.activeIndicator.drawsOutline,
            horizontal: horizontal
        )
    }

    /// Whether the item draws its hover — the one answer the flat
    /// and the glass paints read; the current Space never does
    /// (#2645).
    var showsHover: Bool { !isActive && (isHovered || isDragHovered) }

    private var fillColor: NSColor {
        if isActive, style.hasBox {
            return NSColor(kiwiFill: style.fillColor)
        }
        if isActive { return .clear }
        if showsHover {
            return NSColor(kiwiHex: style.hoverFillColor)
        }
        guard style.hasBox else {
            return .clear
        }
        return NSColor(kiwiFill: style.fillColor)
    }

    var stateColor: NSColor {
        // The layer item takes the current-Space ink: it exists
        // to be noticed, and it is never "not current" (#1169).
        if isActive || space == nil {
            return NSColor(kiwiHex: style.activeItemColor)
        }
        if isHovered || isDragHovered {
            return NSColor(kiwiHex: style.hoverItemColor)
        }
        // An empty Space dims under either content (#1683).
        if heldWindows == 0 {
            return NSColor(kiwiHex: style.emptyItemColor)
        }
        return NSColor(kiwiHex: style.idleItemColor)
    }

    /// A symbol identifier's weight, here and in a hidden bar's
    /// hovered mark (#761), so the two draw one Space alike.
    nonisolated static let identifierSymbolWeight: NSFont.Weight = .regular

    private func styleIdentifier() {
        switch spaceGlyph {
        case .symbol(let name):
            identifierLabel.isHidden = true
            identifierImage.isHidden = false
            identifierImage.image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: nil
            )
            identifierImage.symbolConfiguration =
                NSImage.SymbolConfiguration(
                    pointSize: identifierFont,
                    weight: Self.identifierSymbolWeight
                )
            identifierImage.contentTintColor = stateColor
        case .text(let text, let tinted):
            identifierImage.isHidden = true
            identifierLabel.isHidden = false
            identifierLabel.stringValue = text
            identifierLabel.textColor =
                tinted ? stateColor : .labelColor
            identifierLabel.alphaValue =
                tinted ? 1 : untintedAlpha
        }
    }

    private func styleApps() {
        for (index, app) in apps.enumerated() {
            guard index < appViews.count else { break }
            // A hovered glyph takes the focused glyph's look.
            let lit = glyphIsHovered(index)
            if let glyphField = appViews[index] as? NSTextField {
                glyphField.stringValue = app.glyph ?? ""
                glyphField.font =
                    AppFont.font(size: glyphFontSize)
                    ?? .systemFont(ofSize: glyphFontSize)
                glyphField.textColor =
                    lit || (app.focused && isActive)
                    ? NSColor(kiwiHex: style.focusedItemColor)
                    : stateColor
            } else {
                appViews[index].alphaValue =
                    lit ? 1 : untintedAppAlpha(focused: app.focused)
            }
        }
    }

    /// Three-tier alpha ladder for untinted app glyphs (QA 2026-07-19).
    private func untintedAppAlpha(
        focused: Bool,
        count: Bool = false
    ) -> CGFloat {
        // A hovered glyph stands out against its dimmed siblings,
        // so the chip's own hover lifts them only while no glyph
        // is hovered.
        if hoveredTarget == nil, isHovered || isDragHovered {
            return 1
        }
        if isDragHovered { return 1 }
        guard isActive else {
            return style.dimFactor
        }
        // The focused app's count badge rests at the middle tier
        // beside its full icon (#2650).
        return focused && !count
            ? 1 : style.activeDimFactor
    }

    /// The active indicator this item draws, nil while it draws
    /// none: the accent and the rim beneath it read it alike.
    var drawnIndicator: SpaceBarStyle.ActiveIndicator? {
        isActive ? style.activeIndicator : nil
    }

    private func styleAccent() {
        accent.isHidden = drawnIndicator == nil
        accent.paint = BarAccent.sheen(
            style.highlightColor,
            outline: style.activeIndicator.drawsOutline
                ? style.resolvedHighlightWidth : nil,
            strength: style.sheen,
            drawn: isActive
        )
        guard isActive else { return }
        let ink = BarAccent.flatInk(style.highlightColor, sheen: style.sheen)
        switch style.activeIndicator {
        case .outline:
            accent.layer?.backgroundColor = nil
            accent.layer?.borderColor = ink
            accent.layer?.borderWidth = style.resolvedHighlightWidth
            accent.layer?.cornerRadius =
                BarAccent.outline(
                    in: bounds,
                    radius: cornerRadius,
                    shelf: style.shelf
                ).radius
        case .edgeMark:
            accent.layer?.borderWidth = 0
            accent.layer?.cornerRadius = 0
            accent.layer?.backgroundColor = ink
        }
    }

    var identifierFont: CGFloat {
        style.identifierFontSize(forDepth: depth)
    }

    var glyphFontSize: CGFloat {
        style.glyphFontSize(forDepth: depth)
    }
}
