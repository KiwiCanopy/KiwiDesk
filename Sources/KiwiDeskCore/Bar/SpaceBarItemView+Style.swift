import AppKit

/// State-dependent styling for SpaceBarItemView (#293).
extension SpaceBarItemView {
    func restyle() {
        layer?.masksToBounds = false
        layer?.cornerRadius = cornerRadius
        layer?.backgroundColor = fillColor.cgColor
        accentClip.frame = bounds
        accentClip.layer?.masksToBounds = true
        accentClip.layer?.cornerRadius = cornerRadius
        accentClip.layer?.maskedCorners = maskedCorners
        styleIdentifier()
        styleApps()
        styleBadges()
        styleDivider()
        styleAccent()
    }

    /// Structural divider between identifier and app glyphs (QA 2026-07-19).
    private func styleDivider() {
        identifierDivider.isHidden = apps.isEmpty
        identifierDivider.layer?.backgroundColor =
            BarDivider.color(textColor: style.itemColor)
            .cgColor
    }

    /// Alpha for untinted elements (QA 2026-07-19).
    private var untintedAlpha: CGFloat {
        isActive || isHovered || isDragHovered
            ? 1 : style.dimFactor
    }

    /// Styles count and overflow badges (#293).
    private func styleBadges() {
        for (index, app) in apps.enumerated() {
            guard index < badgeViews.count else { break }
            let badge = badgeViews[index]
            badge.isHidden = app.count < 2
            badge.stringValue = "\(app.count)"
            applyBadge(badge, appFocused: app.focused)
        }
        overflowBadge.isHidden = overflow < 1
        overflowBadge.stringValue = "+\(overflow)"
        applyBadge(overflowBadge, appFocused: focusInOverflow)
        styleStateBadges()
    }

    /// Styles sticky / floating corner state badges (#414).
    private func styleStateBadges() {
        for (index, app) in apps.enumerated() {
            guard index < stickyBadgeViews.count,
                index < floatingBadgeViews.count
            else { break }
            applyStateBadge(
                stickyBadgeViews[index],
                shown: style.stickyBadge && app.sticky,
                markHex: stateMarkColors.sticky,
                appFocused: app.focused
            )
            applyStateBadge(
                floatingBadgeViews[index],
                shown: style.stickyBadge && app.floating,
                markHex: stateMarkColors.floating,
                appFocused: app.focused
            )
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
    /// (#470, #955, owner 2026-07-20).
    private func applyBadge(_ badge: NSTextField, appFocused: Bool) {
        badge.layer?.backgroundColor =
            NSColor(kiwiHex: style.groupBadgeColor).cgColor
        badge.textColor =
            NSColor(kiwiHex: style.groupBadgeTextColor)
        badge.alphaValue = untintedAppAlpha(focused: appFocused)
    }

    var cornerRadius: CGFloat {
        style.resolvedCornerRadius(
            forThickness: min(bounds.width, bounds.height)
        )
    }

    /// Corner masking for accent clip (owner 2026-07-20).
    private var maskedCorners: CACornerMask {
        let all: CACornerMask = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
        ]
        if style.hasBox { return all }
        let leading: CACornerMask =
            horizontal
            ? [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let trailing: CACornerMask =
            horizontal
            ? [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            : [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        var corners: CACornerMask = []
        if isFirstInRun { corners.formUnion(leading) }
        if isLastInRun { corners.formUnion(trailing) }
        return corners
    }

    private var fillColor: NSColor {
        if isActive, style.hasBox {
            return NSColor(kiwiHex: style.fillColor)
        }
        if isActive { return .clear }
        if isHovered || isDragHovered {
            return NSColor(kiwiHex: style.hoverFillColor)
        }
        guard style.hasBox else {
            return .clear
        }
        return NSColor(kiwiHex: style.fillColor)
    }

    private var stateColor: NSColor {
        if isActive {
            return NSColor(kiwiHex: style.activeItemColor)
        }
        if isHovered || isDragHovered {
            return NSColor(kiwiHex: style.hoverItemColor)
        }
        return NSColor(kiwiHex: style.itemColor)
    }

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
                    weight: .regular
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
            if let glyphField = appViews[index] as? NSTextField {
                glyphField.stringValue = app.glyph ?? ""
                glyphField.font =
                    AppFont.font(size: glyphSize)
                    ?? .systemFont(ofSize: glyphSize)
                glyphField.textColor =
                    app.focused && isActive
                    ? NSColor(kiwiHex: style.focusedItemColor)
                    : stateColor
            } else {
                appViews[index].alphaValue =
                    untintedAppAlpha(focused: app.focused)
            }
        }
    }

    /// Three-tier alpha ladder for untinted app glyphs (QA 2026-07-19).
    private func untintedAppAlpha(
        focused: Bool
    ) -> CGFloat {
        if isHovered || isDragHovered { return 1 }
        guard isActive else {
            return style.dimFactor
        }
        return focused
            ? 1 : style.activeDimFactor
    }

    private func styleAccent() {
        accent.isHidden = !isActive
        guard isActive else { return }
        let highlight = NSColor(kiwiHex: style.highlightColor)
        switch style.activeIndicator {
        case .outline:
            accent.layer?.backgroundColor = nil
            accent.layer?.borderColor = highlight.cgColor
            accent.layer?.borderWidth = 2
            accent.layer?.cornerRadius =
                style.hasBox
                ? cornerRadius
                : max(0, cornerRadius - BarAccent.capsuleInset)
        case .edgeMark:
            accent.layer?.borderWidth = 0
            accent.layer?.cornerRadius = 0
            accent.layer?.backgroundColor = highlight.cgColor
        case .gap:
            accent.isHidden = true
        }
    }

    var identifierFont: CGFloat {
        style.identifierFontSize(
            forDepth: horizontal ? bounds.height : bounds.width
        )
    }

    var glyphSize: CGFloat {
        style.glyphFontSize(
            forDepth: horizontal ? bounds.height : bounds.width
        )
    }
}
